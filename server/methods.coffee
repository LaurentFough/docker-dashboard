log = logger.bunyan.createLogger name:'method-invocation'

isAuthorized = -> Meteor.user() or not Settings.get('userAccountsEnabled')

loggedMethod = (name, f) -> ->
  if !isAuthorized() then throw new Meteor.Error '403', 'Not authorized'
  log.info method: name, arguments: arguments, client: @connection.clientAddress, user: Meteor.user()?.username
  f.apply @, arguments

logInvocation = (methods) ->
  _.object ([name, loggedMethod(name, func)] for name, func of methods)

getLogs = (q) ->
  result = HTTP.post "#{Settings.get('elasticSearchUrl')}/_search",
    data:
      query:
        filtered:
          query:
            bool: q
      sort:['@timestamp': order: 'desc']
      size: 500
    auth: "#{Settings.get 'elasticSearchAuth'}"

  result = JSON.parse result.content

  if hits = result?.hits?.hits
    hits.map (item) ->
      date: item._source['@timestamp']
      message: item._source.message
  else
    result

Meteor.methods logInvocation
  startApp: Cluster.startApp
  stopInstance: Cluster.stopInstance
  clearInstance: Cluster.clearInstance
  saveApp: Cluster.saveApp
  deleteApp: Cluster.deleteApp
  'storage/buckets/delete': (id) -> Agent.deleteStorageBucket StorageBuckets.findOne(id)?.name
  'storage/buckets/create': (name) -> Agent.createStorageBucket name
  'storage/buckets/copy': (source, destination) -> Agent.copyStorageBucket source, destination

  restartTag: (tag) ->
    for instance in Instances.find('parameters.tags': tag).fetch()
      try
        Cluster.stopInstance instance.project, instance.name
      catch err
        console.log err
    for def in ApplicationDefs.find('tags': tag).fetch()
      try
        Cluster.startApp def.name, def.version, def.name, EJSON.stringify({tags: def.tags})
      catch err
        console.log err

  getLog: (cid) ->
    getLogs must: [term: 'docker.id': cid]

  getInstanceLog: (id) ->
    instance = Instances.findOne _id: id
    if instance?.meta?.id
      getLogs(must: [match_phrase: message: instance.meta.id])
    else if instance?.logs?.bootstrapLog
      [{date: new Date(), message: instance?.logs?.bootstrapLog}]
    else []

Meteor.methods
  getDocs: -> Assets?.getText 'docs.md'
  getRolesForUser: (targetUser) ->
    loggedInUser = Meteor.user
    unless loggedInUser and Roles.userIsInRole(loggedInUser, ['admin'], Roles.GLOBAL_GROUP)
      throw new Meteor.error 403, 'Access denied'
    Roles.getRolesForUser targetUser
  updateRoles: (userId, roles) ->
    loggedInUser = Meteor.user
    unless loggedInUser and Roles.userIsInRole(loggedInUser, ['admin'], Roles.GLOBAL_GROUP)
      throw new Meteor.Error 403, 'Access denied'
    Roles.setUserRoles userId, roles, Roles.GLOBAL_GROUP
  addRole: (userId, role) ->
    loggedInUser = Meteor.user
    unless loggedInUser and Roles.userIsInRole(loggedInUser, ['admin'], Roles.GLOBAL_GROUP)
      throw new Meteor.Error 403, 'Access denied'
    Roles.addUsersToRoles userId, [role], Roles.GLOBAL_GROUP
  regenerateApiKey: (userId) ->
    check userId, Match.OneOf( Meteor.userId(), String )
    newKey = Random.hexString 32
    APIKeys.upsert { "owner": userId }, $set: "key": newKey
  initApiKey: (userId) ->
    check userId, Match.OneOf( Meteor.userId(), String )
    newKey = Random.hexString 32
    APIKeys.insert owner: userId, key: newKey

Meteor.users.after.insert (userId, doc) ->
  if doc.username in Meteor.settings?.ldap?.admins then Meteor.call "initApiKey", @_id
