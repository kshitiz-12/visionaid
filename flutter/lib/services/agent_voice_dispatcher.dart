import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import 'active_node_store.dart';
import 'imu_tracker.dart';
import 'intent_service.dart';
import 'memory_tracker.dart';
import 'priority_audio.dart';
import 'spatial_db.dart';

/// Routes [AgentIntent] actions for the voice home screen.
class AgentVoiceDispatcher {
  AgentVoiceDispatcher({
    required this.db,
    required this.nodes,
    required this.memory,
    required this.imu,
    required this.audio,
    required this.onStatus,
    required this.enqueueAmbient,
    required this.placeEmergencyCall,
    required this.callNamedContact,
  });

  final SpatialDb db;
  final ActiveNodeStore nodes;
  final MemoryTracker memory;
  final ImuTracker imu;
  final PriorityAudio audio;
  final void Function(String status) onStatus;
  final Future<void> Function(String text) enqueueAmbient;
  final Future<String> Function() placeEmergencyCall;
  final Future<String> Function(String displayName) callNamedContact;

  /// Returns true when the agent fully handled the utterance.
  Future<bool> dispatch(AgentIntent intent, {BuildContext? context}) async {
    switch (intent.type) {
      case AgentIntentType.findObject:
        return _findObject(intent, context: context);
      case AgentIntentType.navigate:
        return _navigate(intent, context: context);
      case AgentIntentType.teachRoute:
        return _teachRoute(intent);
      case AgentIntentType.storeMemory:
        return _storeMemory(intent);
      case AgentIntentType.emergency:
        return _emergency();
      case AgentIntentType.callContact:
        return _callContact(intent);
      case AgentIntentType.contactNotFound:
        return _contactNotFound(intent);
      case AgentIntentType.rateLimited:
        final line = intent.spokenHint.isNotEmpty
            ? intent.spokenHint
            : 'API quota limit reached. Please try again in a moment.';
        await enqueueAmbient(line);
        onStatus(line);
        return true;
      case AgentIntentType.generalQa:
        return false;
    }
  }

  Future<bool> _callContact(AgentIntent intent) async {
    final name = intent.target.trim();
    if (name.isEmpty) {
      await enqueueAmbient('Who should I call? Say the name.');
      return true;
    }
    final result = await callNamedContact(name);
    try {
      await audio.enqueue(
        PriorityUtterance(
          tier: AudioPriorityTier.ambient,
          text: result,
        ),
      );
    } on PriorityAudioException {
      await enqueueAmbient(result);
    }
    onStatus(result);
    return true;
  }

  Future<bool> _contactNotFound(AgentIntent intent) async {
    final name = intent.target.trim();
    final line = name.isEmpty
        ? 'I could not find that contact in your phone. '
            'Save them with the name or nickname you use, then try again.'
        : 'I could not find $name in your phone contacts. '
            'Save $name as the contact name or nickname, then try again.';
    await enqueueAmbient(line);
    onStatus(line);
    return true;
  }

  Future<bool> _findObject(AgentIntent intent, {BuildContext? context}) async {
    final query =
        intent.objectLabel.isNotEmpty ? intent.objectLabel : intent.target;
    if (query.isEmpty) {
      await enqueueAmbient(
        'What should I look for? Say find my purse, or find the keys.',
      );
      return true;
    }
    try {
      final recall = await memory.locateLastSeen(query);
      await audio.enqueue(
        PriorityUtterance(
          tier: AudioPriorityTier.ambient,
          text: recall.spoken,
        ),
      );
      onStatus(recall.spoken);
    } on MemoryTrackerNotFoundException {
      await enqueueAmbient(
        'I have no memory of $query yet. Opening live find.',
      );
      if (context != null && context.mounted) {
        context.push('/live?target=${Uri.encodeQueryComponent(query)}');
      }
    } on MemoryTrackerException catch (error) {
      await enqueueAmbient(error.message);
    } on PriorityAudioException catch (error) {
      await enqueueAmbient(error.message);
    }
    return true;
  }

  Future<bool> _navigate(AgentIntent intent, {BuildContext? context}) async {
    final destQuery =
        intent.nodeId.isNotEmpty ? intent.nodeId : intent.target;
    if (destQuery.isEmpty) {
      await enqueueAmbient('Where should I take you? Name a saved place.');
      return true;
    }
    final active = nodes.activeNodeId;
    if (active == null || active.isEmpty) {
      await enqueueAmbient(
        'Set your current place first. Say I am at my couch.',
      );
      return true;
    }
    final dest = await db.resolveNode(destQuery);
    if (dest == null) {
      await enqueueAmbient(
        'I do not know the place $destQuery yet. Teach me with Follow Me.',
      );
      return true;
    }
    final path = await db.findShortestPath(
      fromNodeId: active,
      toNodeId: dest.id,
    );
    if (path == null) {
      await enqueueAmbient(
        "I don't have a mapped path between those points yet. "
        "You can teach me by saying Follow me.",
      );
      return true;
    }
    if (path.isEmpty) {
      await enqueueAmbient('You are already at ${dest.label}.');
      return true;
    }
    final first = path.first;
    final nextNode = await db.getNode(first.toNode);
    final line =
        'Walk toward ${nextNode?.label ?? first.toNode}, about '
        '${first.distanceMeters.toStringAsFixed(1)} meters, '
        '${first.stepCount} steps. '
        '${path.length > 1 ? '${path.length} segments total.' : 'Last segment.'}';
    try {
      final heading = first.headingDegrees % 360;
      final signed = heading > 180 ? heading - 360 : heading;
      await audio.enqueue(
        PriorityUtterance(
          tier: AudioPriorityTier.navVector,
          text: line,
          angleXDegrees: signed.clamp(-30, 30).toDouble(),
        ),
      );
    } on PriorityAudioCooldownSkip {
      await enqueueAmbient(line);
    } on PriorityAudioException {
      await enqueueAmbient(line);
    }
    onStatus(line);
    if (context != null && context.mounted) {
      context.push('/live');
    }
    return true;
  }

  Future<bool> _teachRoute(AgentIntent intent) async {
    if (imu.isTeaching) {
      final toQuery =
          intent.nodeId.isNotEmpty ? intent.nodeId : intent.target;
      if (toQuery.isEmpty) {
        await enqueueAmbient(
          'Name the destination place to finish Follow Me. '
          'For example, say Follow me to the kitchen.',
        );
        return true;
      }
      final toNode = await ensureNamedNode(toQuery, intent.target);
      try {
        final edge = await imu.finishTeaching(toNodeId: toNode.id);
        await imu.stop();
        await enqueueAmbient(
          'Saved route ${edge.fromNode} to ${edge.toNode}, '
          '${edge.stepCount} steps, '
          '${edge.distanceMeters.toStringAsFixed(1)} meters. '
          'Camera feed is not required for path recording.',
        );
      } on ImuTrackerException catch (error) {
        await enqueueAmbient(error.message);
      }
      return true;
    }

    // Compound: "I am at my couch follow me" → set place, then teach.
    if (intent.setPlaceThenTeach) {
      final placeQuery =
          intent.nodeId.isNotEmpty ? intent.nodeId : intent.target;
      if (placeQuery.isEmpty) {
        await enqueueAmbient(
          'Say the place first, for example I am at my couch follow me.',
        );
        return true;
      }
      final fromNode = await ensureNamedNode(placeQuery, intent.target);
      await nodes.setActive(fromNode.id);
      try {
        await imu.startTeaching(fromNodeId: fromNode.id);
        await enqueueAmbient(
          'Started route recording from ${fromNode.label}. '
          'Walk to your destination and say Follow me to Kitchen. '
          'Camera feed is not required for path recording.',
        );
      } on ImuTrackerException catch (error) {
        await enqueueAmbient(error.message);
      }
      return true;
    }

    final active = nodes.activeNodeId;
    if (active == null || active.isEmpty) {
      final fromQuery =
          intent.nodeId.isNotEmpty ? intent.nodeId : intent.target;
      if (fromQuery.isEmpty) {
        await enqueueAmbient(
          'Set your starting place first. Say I am at my couch, then Follow me. '
          'Camera feed is not required for path recording.',
        );
        return true;
      }
      final fromNode = await ensureNamedNode(fromQuery, intent.target);
      await nodes.setActive(fromNode.id);
    }

    try {
      final fromId = nodes.requireActive();
      final fromNode = await db.getNode(fromId);
      await imu.startTeaching(fromNodeId: fromId);
      await enqueueAmbient(
        'Started route recording from ${fromNode?.label ?? fromId}. '
        'Walk to your destination and say Follow me to Kitchen. '
        'Camera feed is not required for path recording.',
      );
    } on ImuTrackerException catch (error) {
      await enqueueAmbient(error.message);
    } on StateError catch (error) {
      await enqueueAmbient(error.message);
    }
    return true;
  }

  Future<bool> _storeMemory(AgentIntent intent) async {
    final placeQuery =
        intent.nodeId.isNotEmpty ? intent.nodeId : intent.target;
    if (placeQuery.isNotEmpty) {
      final node = await ensureNamedNode(placeQuery, intent.target);
      await nodes.setActive(node.id);
      await enqueueAmbient(
        intent.memoryText.isEmpty
            ? 'Okay. I will remember you are at ${node.label}.'
            : 'Saved. You are at ${node.label}. ${intent.memoryText}',
      );
      return true;
    }
    if (intent.memoryText.isNotEmpty) {
      await enqueueAmbient('Noted: ${intent.memoryText}');
      return true;
    }
    await enqueueAmbient(
      'Tell me the place to remember, for example I am at my couch.',
    );
    return true;
  }

  Future<bool> _emergency() async {
    final result = await placeEmergencyCall();
    try {
      await audio.enqueue(
        PriorityUtterance(
          tier: AudioPriorityTier.critical,
          text: result,
        ),
      );
    } on PriorityAudioException {
      await enqueueAmbient(result);
    }
    onStatus(result);
    return true;
  }

  Future<SpatialNode> ensureNamedNode(String query, String fallbackLabel) async {
    final existing = await db.resolveNode(query);
    if (existing != null) {
      return existing;
    }
    final label =
        (fallbackLabel.trim().isNotEmpty ? fallbackLabel : query).trim();
    final id = _slug(label);
    if (id.isEmpty) {
      throw const SpatialDbQueryException(
        'Cannot create a node from an empty place name.',
      );
    }
    final node = SpatialNode(id: id, label: label, type: 'place');
    await db.upsertNode(node);
    return node;
  }

  String _slug(String label) {
    return label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
