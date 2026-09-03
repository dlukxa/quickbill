void main() {
  var list = List.generate(105, (i) => i);
  var chunks = [];
  for (var i = 0; i < list.length; i += 50) {
    chunks.add(list.sublist(i, i + 50 > list.length ? list.length : i + 50));
  }
  print(chunks.length);
}
