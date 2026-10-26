import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project.dart';
import 'edge_api.dart';

class ProjectGalleryService {
  ProjectGalleryService(this._client, this._edgeApi);

  factory ProjectGalleryService.fromInitialized() {
    final client = Supabase.instance.client;
    return ProjectGalleryService(client, EdgeApi(client));
  }

  static const bucketName = 'project-gallery';
  static const maxFileBytes = 100 * 1024 * 1024;
  static const _extensions = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
  };

  final SupabaseClient _client;
  final EdgeApi _edgeApi;
  final Random _random = Random.secure();

  Future<ProjectGallery?> getGallery(String projectId) async {
    final row = await _client
        .from('project_galleries')
        .select('id,project_id,title,description,allow_download,is_active')
        .eq('project_id', projectId)
        .maybeSingle();
    return row == null ? null : ProjectGallery.fromJson(row);
  }

  Future<ProjectGallery> saveGallery(ProjectGallery gallery) async {
    final values = gallery.toJson(includeId: false);
    final query = gallery.id == null
        ? _client.from('project_galleries').insert(values)
        : _client
            .from('project_galleries')
            .update(values)
            .eq('id', gallery.id!);
    final row = await query
        .select('id,project_id,title,description,allow_download,is_active')
        .single();
    return ProjectGallery.fromJson(row);
  }

  Future<List<ProjectGalleryMedia>> getMedia(String galleryId) async {
    final rows = await _client
        .from('project_gallery_media')
        .select()
        .eq('gallery_id', galleryId)
        .order('sort_order')
        .order('created_at');
    return rows.map(ProjectGalleryMedia.fromJson).toList();
  }

  Future<Map<String, String>> createSignedUrls(
    List<ProjectGalleryMedia> media,
  ) async {
    final paths = media.map((item) => item.storagePath).toList();
    if (paths.isEmpty) {
      return const {};
    }
    final signed = await _client.storage
        .from(bucketName)
        .createSignedUrlsResult(paths, 3600);
    final urls = <String, String>{};
    for (final result in signed) {
      switch (result) {
        case SignedUrlSuccess(:final path, :final signedUrl):
          for (final item in media) {
            if (item.storagePath == path && item.id != null) {
              urls[item.id!] = signedUrl;
              break;
            }
          }
        case SignedUrlFailure(:final path, :final error):
          throw StateError(
            'Signierter Galerie-Link für "$path" fehlgeschlagen: $error',
          );
      }
    }
    return urls;
  }

  Future<String> issueShareLink(ProjectGallery gallery) {
    final galleryId = gallery.id;
    if (galleryId == null) {
      throw StateError('Die Galerie muss zuerst gespeichert werden.');
    }
    return _edgeApi.issueProjectGalleryLink(galleryId);
  }

  Future<void> revokeShareLink(ProjectGallery gallery) {
    final galleryId = gallery.id;
    if (galleryId == null) {
      throw StateError('Die Galerie hat keine gültige ID.');
    }
    return _edgeApi.revokeProjectGalleryLink(galleryId);
  }

  Future<List<ProjectGalleryMedia>> uploadFiles({
    required ProjectGallery gallery,
    required List<PlatformFile> files,
  }) async {
    final user = _client.auth.currentUser;
    final galleryId = gallery.id;
    if (user == null || galleryId == null) {
      throw StateError('Zum Hochladen ist eine gespeicherte Galerie nötig.');
    }

    final validated = <({PlatformFile file, String extension, String mime})>[];
    for (final file in files) {
      final extension = file.extension?.toLowerCase();
      if (extension == null || !_extensions.containsKey(extension)) {
        throw FormatException(
          '„${file.name}“ hat ein nicht unterstütztes Format. Erlaubt sind JPG, PNG, WebP, GIF, MP4, MOV und WebM.',
        );
      }
      final mimeType = _extensions[extension]!;
      if (file.size <= 0 || file.size > maxFileBytes) {
        throw FormatException(
          '„${file.name}“ ist leer oder größer als 100 MB.',
        );
      }
      if (file.bytes == null) {
        throw FormatException(
          'Die Datei „${file.name}“ konnte nicht gelesen werden.',
        );
      }
      validated.add((
        file: file,
        extension: extension,
        mime: mimeType,
      ));
    }

    final uploadedPaths = <String>[];
    final insertedIds = <String>[];
    final uploadedItems = <ProjectGalleryMedia>[];
    try {
      final existing = await getMedia(galleryId);
      var sortOrder = existing.length;
      for (final item in validated) {
        final mediaId = _newId();
        final path = '${user.id}/$galleryId/$mediaId.${item.extension}';
        await _client.storage.from(bucketName).uploadBinary(
              path,
              item.file.bytes!,
              fileOptions: FileOptions(
                contentType: item.mime,
                upsert: false,
              ),
            );
        uploadedPaths.add(path);
        final row = await _client
            .from('project_gallery_media')
            .insert({
              'gallery_id': galleryId,
              'title': _displayName(item.file.name),
              'storage_path': path,
              'mime_type': item.mime,
              'file_size': item.file.size,
              'sort_order': sortOrder++,
            })
            .select()
            .single();
        final media = ProjectGalleryMedia.fromJson(row);
        insertedIds.add(media.id!);
        uploadedItems.add(media);
      }
    } catch (error) {
      if (insertedIds.isNotEmpty) {
        await _client
            .from('project_gallery_media')
            .delete()
            .inFilter('id', insertedIds);
      }
      if (uploadedPaths.isNotEmpty) {
        await _client.storage.from(bucketName).remove(uploadedPaths);
      }
      rethrow;
    }
    return uploadedItems;
  }

  Future<void> deleteMedia(ProjectGalleryMedia media) async {
    final id = media.id;
    if (id == null) {
      throw StateError('Medium hat keine gültige ID.');
    }
    await _client.from('project_gallery_media').delete().eq('id', id);
    await _client.storage.from(bucketName).remove([media.storagePath]);
  }

  String _newId() {
    final value = List<int>.generate(16, (_) => _random.nextInt(256));
    return value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  String _displayName(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }
}
