/// Berechnet einen CRC32-Hash für einen gegebenen String.
///
/// Verwendet das standardisierte CRC32-Verfahren (IEEE 802.3).
/// Das Ergebnis ist ein vorzeichenloser 32-Bit-Integer.
class CRC32 {
  static final List<int> _table = _buildTable();

  static List<int> _buildTable() {
    final table = List<int>.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      int crc = i;
      for (int j = 0; j < 8; j++) {
        if (crc & 1 == 1) {
          crc = (crc >> 1) ^ 0xEDB88320;
        } else {
          crc >>= 1;
        }
      }
      table[i] = crc;
    }
    return table;
  }

  /// Berechnet den CRC32-Hash der Zeichenkodierung von [data].
  ///
  /// Der Rückgabewert ist ein vorzeichenloser 32-Bit-Integer (0 … 2³²−1).
  static int compute(String data) {
    int crc = 0xFFFFFFFF;
    final bytes = data.codeUnits;
    for (final byte in bytes) {
      crc = (crc >> 8) ^ _table[(crc ^ byte) & 0xFF];
    }
    return crc ^ 0xFFFFFFFF;
  }
}