newEvent = (type, subject, action, info) ->
  Events.insert
    type: type
    subject: subject
    action: action
    info: info
    timestamp: new Date()

newSuccessEvent = (subject, action, info) -> newEvent 'success', subject, action, info
newWarningEvent = (subject, action, info) -> newEvent 'warning', subject, action, info
newInfoEvent    = (subject, action, info) -> newEvent 'info', subject, action, info

starting = true
Instances.find().observe
  changed: (newDoc, oldDoc) ->
    if newDoc?.state == 'running' && oldDoc?.state != 'running'
      newSuccessEvent 'instance', 'started', name: newDoc.name unless starting
    if newDoc?.state == 'stopping' && oldDoc?.state != 'stopping'
      newInfoEvent 'instance', 'stopping', (name: newDoc.name, user: newDoc.stoppedBy) unless starting
  removed:  (doc) -> newWarningEvent 'instance', 'stopped', name: doc.name unless starting
  added:    (doc) ->
    unless starting
      newInfoEvent 'instance', 'starting', (name: doc.name, user: doc.startedBy)

ApplicationDefs.find().observe
  changed: (doc) ->
    newSuccessEvent 'appdef', 'changed', {name: doc.name, version: doc.version} unless starting
  removed: (doc) ->
    newWarningEvent 'appdef', 'removed', {name: doc.name, version: doc.version} unless starting
  added: (doc) ->
    newSuccessEvent 'appdef', 'added', {name: doc.name, version: doc.version} unless starting

StorageBuckets.find({}, {fields: name: 1, isLocked: 1}).observe
  changed: (doc, oldDoc) ->
    if doc.isLocked and not oldDoc.isLocked
      newInfoEvent 'storage', 'locked', {name: doc.name} unless starting
    else
      newInfoEvent 'storage', 'unlocked', {name: doc.name} unless starting
  removed: (doc) ->
    newWarningEvent 'storage', 'removed', {name: doc.name} unless starting
  added: (doc) ->
    newSuccessEvent 'storage', 'added', {name: doc.name} unless starting

starting = false
