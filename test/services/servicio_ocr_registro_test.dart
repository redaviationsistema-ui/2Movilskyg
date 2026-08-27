import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/services/servicio_ocr_registro.dart';

void main() {
  group('RegistrationOcrService.parseIneText', () {
    test('separa nombres y apellidos compuestos del bloque NOMBRE del INE', () {
      final parsed = RegistrationOcrService.parseIneText('''
MEXICO INSTITUTO NACIONAL ELECTORAL
CREDENCIAL PARA VOTAR
NOMBRE
DE JESUS
FLORES
KEVIN LAEL
DOMICILIO
AV INDEPENDENCIA 7
LERMA, MEX.
CURP
JEFK030206HMCSLVA8
''');

      expect(parsed['name'], 'KEVIN LAEL');
      expect(parsed['last_name'], 'DE JESUS FLORES');
    });

    test(
      'mantiene apellido simple y nombres de otro usuario sin hardcodear',
      () {
        final parsed = RegistrationOcrService.parseIneText('''
INSTITUTO NACIONAL ELECTORAL
NOMBRE
LOPEZ
ANA MARIA
CURP
LOAA990101MMCRRN09
''');

        expect(parsed['name'], 'ANA MARIA');
        expect(parsed['last_name'], 'LOPEZ');
      },
    );
  });
}
