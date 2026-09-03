const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { google } = require('googleapis');

admin.initializeApp();
const db = admin.firestore();

const PACKAGE_NAME = 'lk.unio.quickbillpos';
const SUBSCRIPTION_PRODUCT_ID = 'quickbill_premium_monthly';

// Initialize Google Play Developer API Client with Service Account
async function getPlayBillingClient() {
  const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  return google.androidpublisher({
    version: 'v3',
    auth: await auth.getClient(),
  });
}

/**
 * Callable Function: Verify a Google Play Subscription purchase token
 */
exports.verifyGooglePlaySubscription = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { purchaseToken, productId, shopUid } = data;
  const targetShopUid = shopUid || context.auth.uid;

  if (!purchaseToken) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing purchaseToken.');
  }

  try {
    const playClient = await getPlayBillingClient();

    // Query Google Play Developer API Subscriptions v2
    const res = await playClient.purchases.subscriptionsv2.get({
      packageName: PACKAGE_NAME,
      token: purchaseToken,
    });

    const subData = res.data;
    const subscriptionState = subData.subscriptionState;
    // SUBSCRIPTION_STATE_PENDING: 1, SUBSCRIPTION_STATE_ACTIVE: 2, SUBSCRIPTION_STATE_PAUSED: 3,
    // SUBSCRIPTION_STATE_IN_GRACE_PERIOD: 4, SUBSCRIPTION_STATE_ON_HOLD: 5, SUBSCRIPTION_STATE_CANCELED: 6, SUBSCRIPTION_STATE_EXPIRED: 7

    let status = 'expired';
    let isTrial = false;
    let isAutoRenewing = true;

    if (subscriptionState === 'SUBSCRIPTION_STATE_ACTIVE') {
      status = 'active';
    } else if (subscriptionState === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD') {
      status = 'inGracePeriod';
    } else if (subscriptionState === 'SUBSCRIPTION_STATE_CANCELED') {
      status = 'cancelled';
      isAutoRenewing = false;
    } else if (subscriptionState === 'SUBSCRIPTION_STATE_PAUSED' || subscriptionState === 'SUBSCRIPTION_STATE_ON_HOLD') {
      status = 'paused';
    } else {
      status = 'expired';
    }

    // Extract line item & expiry
    let expiryDate = null;
    if (subData.lineItems && subData.lineItems.length > 0) {
      const lineItem = subData.lineItems[0];
      if (lineItem.expiryTime) {
        expiryDate = lineItem.expiryTime;
      }
      if (lineItem.offerDetails && lineItem.offerDetails.offerTags) {
        isTrial = lineItem.offerDetails.offerTags.includes('trial') || lineItem.offerDetails.offerTags.includes('free-trial');
      }
    }

    // Acknowledge subscription if not yet acknowledged
    if (subData.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING') {
      await playClient.purchases.subscriptions.acknowledge({
        packageName: PACKAGE_NAME,
        subscriptionId: productId || SUBSCRIPTION_PRODUCT_ID,
        token: purchaseToken,
      });
    }

    // Write verified entitlement state to Firestore
    const subscriptionPayload = {
      productId: productId || SUBSCRIPTION_PRODUCT_ID,
      basePlanId: 'monthly-base-plan',
      planTier: 'premium',
      status: status,
      isTrial: isTrial,
      isAutoRenewing: isAutoRenewing,
      expiryDate: expiryDate,
      purchaseToken: purchaseToken,
      platform: 'google_play',
      lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('users').doc(targetShopUid).set({
      subscription: subscriptionPayload,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return {
      success: true,
      status: status,
      expiryDate: expiryDate,
      isTrial: isTrial,
    };
  } catch (error) {
    console.error('Google Play Verification Error:', error);
    throw new functions.https.HttpsError('internal', `Verification failed: ${error.message}`);
  }
});

/**
 * Pub/Sub Trigger: Real-Time Developer Notifications (RTDN) from Google Play
 * Automatically syncs renewals, cancellations, grace periods, and expirations in background
 */
exports.googlePlayBillingWebhook = functions.pubsub.topic('play-billing-notifications').onPublish(async (message) => {
  const messageData = message.data ? Buffer.from(message.data, 'base64').toString() : null;
  if (!messageData) return;

  const event = JSON.parse(messageData);
  const subNotification = event.subscriptionNotification;
  if (!subNotification) return;

  const { notificationType, purchaseToken, subscriptionId } = subNotification;
  console.log(`Received RTDN Notification: Type ${notificationType}, Sub: ${subscriptionId}`);

  try {
    // Look up shop by purchaseToken
    const snapshot = await db.collection('users')
      .where('subscription.purchaseToken', '==', purchaseToken)
      .limit(1)
      .get();

    if (snapshot.empty) {
      console.warn(`No user found for token: ${purchaseToken}`);
      return;
    }

    const userDoc = snapshot.docs[0];
    const shopUid = userDoc.id;

    const playClient = await getPlayBillingClient();
    const res = await playClient.purchases.subscriptionsv2.get({
      packageName: PACKAGE_NAME,
      token: purchaseToken,
    });

    const subData = res.data;
    let status = 'active';
    let isAutoRenewing = true;
    let expiryDate = null;

    if (subData.lineItems && subData.lineItems.length > 0) {
      expiryDate = subData.lineItems[0].expiryTime;
    }

    // Google Play RTDN Notification Types:
    // 1: RECOVERED, 2: RENEWED, 3: CANCELED, 4: PURCHASED, 5: ON_HOLD, 6: IN_GRACE_PERIOD,
    // 7: RESTARTED, 8: PRICE_CHANGE_CONFIRMED, 9: DEFERRED, 10: PAUSED, 12: REVOKED, 13: EXPIRED
    switch (notificationType) {
      case 2: // RENEWED
        status = 'active';
        break;
      case 3: // CANCELED
        status = 'cancelled';
        isAutoRenewing = false;
        break;
      case 5: // ON_HOLD
      case 10: // PAUSED
        status = 'paused';
        break;
      case 6: // IN_GRACE_PERIOD
        status = 'inGracePeriod';
        break;
      case 12: // REVOKED
      case 13: // EXPIRED
        status = 'expired';
        break;
      default:
        status = subData.subscriptionState === 'SUBSCRIPTION_STATE_ACTIVE' ? 'active' : 'expired';
    }

    await db.collection('users').doc(shopUid).update({
      'subscription.status': status,
      'subscription.isAutoRenewing': isAutoRenewing,
      'subscription.expiryDate': expiryDate,
      'subscription.lastVerifiedAt': admin.firestore.FieldValue.serverTimestamp(),
      'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Updated subscription for shop ${shopUid} to status ${status}`);
  } catch (error) {
    console.error('Error processing RTDN notification:', error);
  }
});
