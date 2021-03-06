collection = new Mongo.Collection 'settings'
key = key: (Meteor.settings.public?.key or 'default')

@Settings =
  collection: collection
  get: (field) ->
    settings = Settings.collection.findOne(key)
    if field
      s = settings?[field]
      if s isnt undefined then s else
        console.warn "'#{field}' setting is not defined."
        ''
    else
      console.warn "Settings.get() is deprecated. Please use Settings.get('field') or Settings.all() instead."
      settings or {}
  all: -> Settings.collection.findOne(key)
  set: (field, value) ->
    set = {}; set[field] = value
    Settings.collection.update key, {$set: set}, (err) ->
      console.error err if err
  cursor: -> collection.find(key)

Settings.collection.allow
  insert: -> true
  update: -> true
  remove: -> true

Settings.schema = new SimpleSchema
  key: type: String
  project: type: String
  elasticSearchUrl: type: String
  elasticSearchAuth: type: String
  agentAuthToken:
    type: String
    autoform:
      type: 'hidden'
  agentUrl: type: [String]
  isAdmin: type: Boolean
  userAccountsEnabled:
    type: Boolean
    optional: true
  remoteAppstoreUrl:
    type: String
    optional: true

Settings.collection.attachSchema Settings.schema

Meteor.startup ->
  if Meteor.server
    Meteor.publish null, -> Settings.cursor()

    settings = Meteor.settings
    aurl = settings?.agentUrl
    Settings.collection.upsert key, $set:
      key: settings?.public?.key or 'default'
      project: settings?.project or 'undef'
      elasticSearchUrl: settings?.elasticSearchUrl or 'http://elasticsearch.isd.ictu:9200'
      elasticSearchAuth: settings?.elasticSearchAuth or 'user:pwd'
      agentAuthToken: settings?.agentAuthToken
      agentUrl:
        if aurl
          if aurl.constructor is Array then aurl else [aurl]
        else
          ['http://agent']
      isAdmin: settings?.admin or settings?.public?.admin or false
      userAccountsEnabled: settings?.userAccountsEnabled or false
      remoteAppstoreUrl: settings?.remoteAppstoreUrl or settings?.public?.remoteAppstoreUrl or ''
