// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setlist_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SetlistModelAdapter extends TypeAdapter<SetlistModel> {
  @override
  final int typeId = 0;

  @override
  SetlistModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SetlistModel(
      id: fields[0] as String,
      title: fields[1] as String,
      titleColor: fields[2] as String,
      themeColor: fields[3] as String,
      songIds: (fields[4] as List).cast<String>(),
      isActive: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SetlistModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.titleColor)
      ..writeByte(3)
      ..write(obj.themeColor)
      ..writeByte(4)
      ..write(obj.songIds)
      ..writeByte(5)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetlistModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
