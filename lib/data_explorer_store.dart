import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// A view model state that represents a single node item in a json object tree.
/// A decoded json object can be converted to a [NodeViewModelState] by calling
/// the [buildViewModelNodes] method.
///
/// A node item can be eiter a class root, an array or a single
/// class/array field.
///
///
/// The string [key] is the same as the json key, unless this node is an element
/// if an array, then its key is its index in the array.
///
/// The node [value] behaviour depends on what this node represents, if it is
/// a property (from json: "key": "value"), then the value is the actual
/// property value, one of [num], [String], [bool], [Null]. Since this node
/// represents a single property, both [isClass] and [isArray] are false.
///
/// If this node represents a class, [value] contains a
/// [Map<String, NodeViewModelState>] with this node's children. In this case
/// [isClass] is true.
///
/// If this node represents an array, [value] contains a
/// [List<NodeViewModelState>] with this node's children. In this case
/// [isArray] is true.
///
/// See also:
/// * [buildViewModelNodes]
class NodeViewModelState extends ChangeNotifier {
  final String key;
  final dynamic value;
  final int treeDepth;
  final bool isClass;
  final bool isArray;
  final int childrenCount;

  bool _isHighlighted = false;
  bool _isCollapsed;

  NodeViewModelState._({
    required this.treeDepth,
    required this.key,
    required this.value,
    this.childrenCount = 0,
    this.isClass = false,
    this.isArray = false,
    bool isCollapsed = true,
  }) : _isCollapsed = isCollapsed;

  factory NodeViewModelState.fromProperty({
    required int treeDepth,
    required String key,
    required dynamic value,
    bool isCollapsed = true,
  }) =>
      NodeViewModelState._(
        key: key,
        value: value,
        treeDepth: treeDepth,
      );

  factory NodeViewModelState.fromClass({
    required int treeDepth,
    required String key,
    required Map<String, NodeViewModelState> value,
    bool isCollapsed = true,
  }) =>
      NodeViewModelState._(
        isClass: true,
        key: key,
        value: value,
        childrenCount: value.keys.length,
        treeDepth: treeDepth,
        isCollapsed: isCollapsed,
      );

  factory NodeViewModelState.fromArray({
    required int treeDepth,
    required String key,
    required List<dynamic> value,
    bool isCollapsed = true,
  }) =>
      NodeViewModelState._(
        isArray: true,
        key: key,
        value: value,
        childrenCount: value.length,
        treeDepth: treeDepth,
        isCollapsed: isCollapsed,
      );

  bool get isHighlighted => _isHighlighted;

  bool get isCollapsed => _isCollapsed;

  bool get isRoot => isClass || isArray;

  Iterable<NodeViewModelState> get children {
    if (isClass) {
      return (value as Map<String, NodeViewModelState>).values;
    } else if (isArray) {
      return value as List<NodeViewModelState>;
    }
    return [];
  }

  void highlight(bool highlight) {
    _isHighlighted = highlight;
    for (var children in children) {
      children.highlight(highlight);
    }
    notifyListeners();
  }

  void collapse() {
    _isCollapsed = true;
    notifyListeners();
  }

  void expand() {
    _isCollapsed = false;
    notifyListeners();
  }
}

Map<String, NodeViewModelState> buildViewModelNodes(
  dynamic object, {
  bool isAllCollapsed = true,
}) {
  if (object is Map<String, dynamic>) {
    return _buildClassNodes(object: object, isAllCollapsed: isAllCollapsed);
  }
  return _buildClassNodes(
    object: {'data': object},
    isAllCollapsed: isAllCollapsed,
  );
}

Map<String, NodeViewModelState> _buildClassNodes({
  required Map<String, dynamic> object,
  required bool isAllCollapsed,
  int treeDepth = 0,
}) {
  final map = <String, NodeViewModelState>{};
  object.forEach((key, value) {
    if (value is Map<String, dynamic>) {
      final subClass = _buildClassNodes(
        object: value,
        treeDepth: treeDepth + 1,
        isAllCollapsed: isAllCollapsed,
      );
      map[key] = NodeViewModelState.fromClass(
        treeDepth: treeDepth,
        key: key,
        value: subClass,
        isCollapsed: isAllCollapsed,
      );
    } else if (value is List) {
      final array = _buildArrayNodes(
        object: value,
        treeDepth: treeDepth,
        isAllCollapsed: isAllCollapsed,
      );
      map[key] = NodeViewModelState.fromArray(
        treeDepth: treeDepth,
        key: key,
        value: array,
        isCollapsed: isAllCollapsed,
      );
    } else {
      map[key] = NodeViewModelState.fromProperty(
        key: key,
        value: value,
        treeDepth: treeDepth,
        isCollapsed: isAllCollapsed,
      );
    }
  });
  return map;
}

List<NodeViewModelState> _buildArrayNodes({
  required List<dynamic> object,
  required bool isAllCollapsed,
  int treeDepth = 0,
}) {
  final array = <NodeViewModelState>[];
  for (int i = 0; i < object.length; i++) {
    final arrayValue = object[i];

    if (arrayValue is Map<String, dynamic>) {
      final classNode = _buildClassNodes(
        object: arrayValue,
        treeDepth: treeDepth + 2,
        isAllCollapsed: isAllCollapsed,
      );
      array.add(
        NodeViewModelState.fromClass(
          key: i.toString(),
          value: classNode,
          treeDepth: treeDepth + 1,
          isCollapsed: isAllCollapsed,
        ),
      );
    } else {
      array.add(
        NodeViewModelState.fromProperty(
          key: i.toString(),
          value: arrayValue,
          treeDepth: treeDepth + 1,
        ),
      );
    }
  }
  return array;
}

List<NodeViewModelState> flatten(dynamic object) {
  if (object is List) {
    return _flattenArray(object as List<NodeViewModelState>);
  }
  return _flattenClass(object as Map<String, NodeViewModelState>);
}

List<NodeViewModelState> _flattenClass(Map<String, NodeViewModelState> object) {
  final flatList = <NodeViewModelState>[];
  object.forEach((key, value) {
    flatList.add(value);

    if (!value.isCollapsed) {
      if (value.value is Map) {
        flatList.addAll(_flattenClass(value.value));
      } else if (value.value is List) {
        flatList.addAll(_flattenArray(value.value));
      }
    }
  });
  return flatList;
}

List<NodeViewModelState> _flattenArray(List<NodeViewModelState> objects) {
  final flatList = <NodeViewModelState>[];
  for (final object in objects) {
    flatList.add(object);
    if (!object.isCollapsed &&
        object.value is Map<String, NodeViewModelState>) {
      flatList.addAll(_flattenClass(object.value));
    }
  }
  return flatList;
}

class DataExplorerStore extends ChangeNotifier {
  final itemScrollController = ItemScrollController();

  List<NodeViewModelState> _displayNodes = [];

  // TODO: maybe the search should be in another store.
  final _searchResults = <NodeViewModelState>[];
  String _searchTerm = '';
  dynamic _jsonObject;

  Iterable<NodeViewModelState> get displayNodes =>
      UnmodifiableListView(_displayNodes);

  String get searchTerm => _searchTerm;

  Iterable<NodeViewModelState> get searchResults =>
      UnmodifiableListView(_searchResults);

  void collapseNode(NodeViewModelState node) {
    if (node.isCollapsed || !node.isRoot) {
      return;
    }

    final nodeIndex = _displayNodes.indexOf(node) + 1;
    final children = _visibleChildrenCount(node) - 1;
    print('Children $children');

    _displayNodes.removeRange(nodeIndex, nodeIndex + children);
    node.collapse();
    notifyListeners();
  }

  void collapseAll() {
    buildNodes(_jsonObject, isAllCollapsed: true);
  }

  void expandNode(NodeViewModelState node) {
    if (!node.isCollapsed || !node.isRoot) {
      return;
    }

    final nodeIndex = _displayNodes.indexOf(node) + 1;
    final nodes = flatten(node.value);
    print('Nodes ${nodes.length}');

    _displayNodes.insertAll(nodeIndex, nodes);
    node.expand();
    notifyListeners();
  }

  void expandAll() {
    buildNodes(_jsonObject, isAllCollapsed: false);
  }

  void search(String term) {
    _searchTerm = term.toLowerCase();
    _searchResults.clear();
    notifyListeners();

    if (term.isNotEmpty) {
      _doSearch();
    }
  }

  Future buildNodes(dynamic jsonObject, {bool isAllCollapsed = false}) async {
    // TODO: remove stopwatch and print.
    Stopwatch stopwatch = Stopwatch()..start();
    final builtNodes = buildViewModelNodes(
      jsonObject,
      isAllCollapsed: isAllCollapsed,
    );
    final flatList = flatten(builtNodes);
    print('Built ${flatList.length} nodes.');
    print('executed in ${stopwatch.elapsed}.');

    _jsonObject = jsonObject;
    _displayNodes = flatList;
    notifyListeners();
  }

  int _visibleChildrenCount(NodeViewModelState node) {
    final children = node.children;
    int count = 1;
    for (final child in children) {
      count =
          child.isCollapsed ? count + 1 : count + _visibleChildrenCount(child);
    }
    return count;
  }

  // TODO: not optimal way to do this. Maybe change to a stream once we leave
  // the SPIKE phase.
  // Also we are scrolling only to the first item for demo purposes.
  Future _doSearch() {
    return Future(() {
      for (int i = 0; i < _displayNodes.length; i++) {
        final node = _displayNodes[i];
        if (node.key.toLowerCase().contains(searchTerm)) {
          _searchResults.add(node);
        }
        if (!node.isRoot) {
          if (node.value.toString().toLowerCase().contains(searchTerm)) {
            _searchResults.add(node);
          }
        }
      }

      if (_searchResults.isNotEmpty) {
        notifyListeners();
        itemScrollController.scrollTo(
          index: _displayNodes.indexOf(_searchResults.first),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }
}
