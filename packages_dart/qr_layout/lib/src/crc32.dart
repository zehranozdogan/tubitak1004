// Standart CRC-32 (IEEE 802.3 / zlib.crc32 ile AYNI: poly 0xEDB88320
// yansıtılmış, init/xorout 0xFFFFFFFF) — dış bağımlılık yok, gerçek
// Python `zlib.crc32` çıktısıyla doğrulandı (bkz. test/crc32_test.dart).

import 'dart:convert';

final List<int> _table = _buildTable();

List<int> _buildTable() {
  final table = List<int>.filled(256, 0);
  for (var i = 0; i < 256; i++) {
    var c = i;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
    }
    table[i] = c;
  }
  return table;
}

int crc32(String input) {
  var crc = 0xFFFFFFFF;
  for (final byte in utf8.encode(input)) {
    crc = _table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
