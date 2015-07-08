Template.appstore.helpers
  apps: -> AppStore.find()
  hash: -> CryptoJS.MD5 "#{@name}#{@version}"

Template.appstore.events
  "click .btn-install-app": (event, template) ->
    Meteor.call 'saveApp', @name, @version, @def
  "click .btn-remove-app": (event, template) ->
    Meteor.call 'removeAppFromStore', @name, @version
  'save-app-def': (e, tpl) ->
    Meteor.call 'saveAppInStore', e.yaml.parsed, e.yaml.raw