import 'dart:convert';
class Audit {
  List<Map<String, dynamic>> _list(dynamic value) =>
      value is List
          ? value
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : const [];
  String _token(dynamic value) {
    return '$value'
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
  }
  String _friendlyChecklistCategory(String value) {
    switch (_token(value)) {
      case 'personal':
        return 'Documentación personal';
      case 'logistics':
        return 'Traslado y presentación';
      case 'operation':
        return 'Información del vuelo';
      case 'passengers':
        return 'Pasajeros';
      case 'service':
        return 'Servicio';
      case 'cabin':
        return 'Cabina';
      case 'safety':
        return 'Seguridad';
      default:
        return value.trim().isEmpty ? 'General' : _naturalizeText(value);
    }
  }
  String _naturalizeText(String value) {
    final cleaned = value.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return 'Actualización';
    return '${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
  }
  List<Map<String, dynamic>> _itemsForChecklist(
    Map<String, dynamic> checklist,
  ) {
    return _list(checklist['items']);
  }
  List<MapEntry<String, List<Map<String, dynamic>>>> _groupedChecklist(
    Map<String, dynamic>? checklist,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item
        in checklist == null
            ? const <Map<String, dynamic>>[]
            : _itemsForChecklist(checklist)) {
      final key = _friendlyChecklistCategory(
        '${item['category'] ?? item['group'] ?? ''}',
      );
      groups.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(item);
    }
    return groups.entries.toList();
  }
  List<int> ids(List<Map<String,dynamic>> items) => _groupedChecklist({'items':items}).expand((g)=>g.value).map((i)=>i['id'] as int).toList();
}
void main() {
 final audit=Audit();
 for(final entry in {'service':['Faltantes registrados','Catering sobrante registrado'], 'operation':['Ruta revisada','Aeronave revisada'], 'cabin':['Limpieza de cabina','Asientos y cinturones','Equipaje asegurado','Baño revisado']}.entries) {
  final items=List.generate(entry.value.length,(i)=><String,dynamic>{'id':i+1,'category':entry.key,'label':entry.value[i],'status':i==0?'pending':'completed'});
  final before=audit.ids(items);
  items.first['status']='completed';
  final after=audit.ids(items);
  final refreshed=(jsonDecode(jsonEncode(items)) as List).map((i)=>Map<String,dynamic>.from(i)).toList();
  final refresh=audit.ids(refreshed);
  if(jsonEncode(before)!=jsonEncode(after)||jsonEncode(before)!=jsonEncode(refresh)) throw StateError('Changed order');
  final changedPayload=audit.ids(refreshed.reversed.toList());
  if(jsonEncode(changedPayload)!=jsonEncode(before.reversed.toList())) throw StateError('Did not follow payload');
  print('${entry.key}: BEFORE=$before AFTER=$after REFRESH_SAME_PAYLOAD=$refresh REFRESH_REVERSED_PAYLOAD=$changedPayload');
 }
}
