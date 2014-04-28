part of globbing.file_list;

class FileList extends Object with ListMixin<String> {
  final Directory directory;

  List<String> _files;

  Glob _glob;

  FileList(this.directory, String pattern, {bool caseSensitive}) {
    if (directory == null) {
      throw new ArgumentError("directory: $directory");
    }

    if (pattern == null) {
      throw new ArgumentError("files: $pattern");
    }

    var isWindows = Platform.isWindows;
    if (caseSensitive == null) {
      if (isWindows) {
        caseSensitive = false;
      } else {
        caseSensitive = true;
      }
    }

    if (Platform.isWindows) {
      pattern = pattern.replaceAll("\\", "/");
    }

    _glob = new Glob(pattern, caseSensitive: caseSensitive);
    _files = _getFiles();
  }

  /**
   * Returns the length.
   */
  int get length {
    return _files.length;
  }

  /**
   * Sets the length;
   */
  void set length(int length) {
    throw new UnsupportedError("length=");
  }


  String operator [](int index) {
    return _files[index];
  }

  void operator []=(int index, String value) {
    throw new UnsupportedError("[]=");
  }

  List<String> _getFiles() {
    var lister = new _DirectoryLister(_glob);
    return lister.list(directory);
  }
}

class _DirectoryLister {
  final Glob glob;

  List<String> _files;

  bool _isWindows;

  int _offset;

  bool _onlyDirectory;

  List<GlobSegment> _segments;

  bool _useStrict;

  _DirectoryLister(this.glob) {
    if (glob == null) {
      throw new ArgumentError("glob: $glob");
    }

    _segments = glob.segments;
  }

  List<String> list(Directory directory) {
    _files = <String>[];
    if (!directory.existsSync()) {
      return _files;
    }

    if (!_segments.isEmpty) {
      _onlyDirectory = _segments.last.onlyDirectory;
    } else {
      _onlyDirectory = false;
    }

    _isWindows = Platform.isWindows;
    if (glob.caseSensitive) {
      if (_isWindows) {
        _useStrict = false;
      } else {
        _useStrict = true;
      }
    } else {
      if (_isWindows) {
        _useStrict = true;
      } else {
        _useStrict = false;
      }
    }

    if (glob.isAbsolute) {
      _offset = 0;
    } else {
      _offset = directory.path.length;
    }

    if (glob.isAbsolute) {
      if (glob.crossesDirectory) {
        _listAbsoluteWithCrossing(directory);
      } else {
        _listAbsoluteWithoutCrossing(directory);
      }
    } else {
      if (_segments[0].crossesDirectory) {
        _listRecursive(directory);
      } else {
        _listRelative(directory, 0);
      }
    }

    return _files;
  }

  void _listAbsoluteWithCrossing(Directory directory) {
    var path = directory.path;
    if (_isWindows) {
      path = path.replaceAll("\\", "/");
    }

    var pathSegments = pathos.split(path);
    var length = pathSegments.length;
    if (length > _segments.length) {
      return;
    }

    for (var i = 0; i < length; i++) {
      var segment = _segments[i];
      if (segment.crossesDirectory) {
        break;
      }

      if (!_segments[i].match(pathSegments[i])) {
        return;
      }
    }

    if (directory.existsSync()) {
      _listRecursive(directory);
    }
  }

  void _listAbsoluteWithoutCrossing(Directory directory) {
    var path = directory.path;
    if (_isWindows) {
      path = path.replaceAll("\\", "/");
    }

    var pathSegments = pathos.split(path);
    var length = pathSegments.length;
    if (length > _segments.length) {
      return;
    }

    for (var i = 0; i < length; i++) {
      if (!_segments[i].match(pathSegments[i])) {
        return;
      }
    }

    if (directory.existsSync()) {
      _listAbsoluteWithoutCrossingStage2(directory, length);
    }
  }

  void _listAbsoluteWithoutCrossingStage2(Directory directory, int level) {
    var segment = _segments[level];
    if (segment.strict && _useStrict) {
      var path = pathos.join(directory.path, segment.pattern);
      directory = new Directory(path);
      var dirExists = directory.existsSync();
      var fileExists = false;
      if (!dirExists) {
        fileExists = new File(path).existsSync();
      }

      if (!(dirExists || fileExists)) {
        return;
      }

      if (level == _segments.length - 1) {
        if (_isWindows) {
          path = path.replaceAll("\\", "/");
        }

        if (segment.onlyDirectory) {
          if (dirExists) {
            _files.add(path);
          }

        } else {
          _files.add(path);
        }

        return;
      }

      if (dirExists) {
        _listAbsoluteWithoutCrossingStage2(directory, level + 1);
      }

      return;
    }

    for (var entry in directory.listSync()) {
      var entryPath = entry.path;
      if (_isWindows) {
        entryPath = entryPath.replaceAll("\\", "/");
      }

      var index = entryPath.lastIndexOf("/");
      String part;
      if (index != -1) {
        part = entryPath.substring(index + 1);
      } else {
        part = entryPath;
      }

      if (!segment.match(part)) {
        continue;
      }

      if (level == _segments.length - 1) {
        if (segment.onlyDirectory) {
          if (entry is Directory) {
            _files.add(entryPath);
          }

        } else {
          _files.add(entryPath);
        }

        continue;
      }

      if (entry is Directory) {
        _listAbsoluteWithoutCrossingStage2(entry, level + 1);
      }
    }
  }

  void _listRecursive(Directory directory) {
    for (var entry in directory.listSync()) {
      var entryPath = entry.path;
      if (_isWindows) {
        entryPath = entryPath.replaceAll("\\", "/");
      }

      var relativePath = entryPath;
      if (_offset > 0) {
        relativePath = entryPath.substring(_offset + 1);
      }

      var isDirectory = entry is Directory;
      if (_onlyDirectory) {
        if (isDirectory) {
          relativePath += "/";
          if (glob.match(relativePath)) {
            _files.add(entryPath);
          }
        }

      } else {
        if (glob.match(relativePath)) {
          _files.add(entryPath);
        }
      }

      if (isDirectory) {
        _listRecursive(entry);
      }
    }
  }

  void _listRelative(Directory directory, int level) {
    var segment = _segments[level];
    if (segment.strict && _useStrict) {
      var path = pathos.join(directory.path, segment.pattern);
      directory = new Directory(path);
      var dirExists = directory.existsSync();
      var fileExists = false;
      if (!dirExists) {
        fileExists = new File(path).existsSync();
      }

      if (!(dirExists || fileExists)) {
        return;
      }

      if (level == _segments.length - 1) {
        if (_isWindows) {
          path = path.replaceAll("\\", "/");
        }

        if (segment.onlyDirectory) {
          if (dirExists) {
            _files.add(path);
          }

        } else {
          _files.add(path);
        }

        _files.add(path);
        return;
      }

      if (dirExists) {
        var index = level + 1;
        var nextSegment = _segments[index];
        if (!nextSegment.crossesDirectory) {
          _listRelative(directory, index);
        } else {
          _listRecursive(directory);
        }
      }

      return;
    }

    for (var entry in directory.listSync()) {
      var entryPath = entry.path;
      if (_isWindows) {
        entryPath = entryPath.replaceAll("\\", "/");
      }

      var index = entryPath.lastIndexOf("/");
      String part;
      if (index != -1) {
        part = entryPath.substring(index + 1);
      } else {
        part = entryPath;
      }

      if (!segment.match(part)) {
        continue;
      }

      if (level == _segments.length - 1) {
        if (segment.onlyDirectory) {
          if (entry is Directory) {
            _files.add(entryPath);
          }

        } else {
          _files.add(entryPath);
        }

        continue;
      }

      if (entry is Directory) {
        var index = level + 1;
        var nextSegment = _segments[index];
        if (!nextSegment.crossesDirectory) {
          _listRelative(entry, index);
        } else {
          _listRecursive(entry);
        }
      }
    }
  }
}
