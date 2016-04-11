Meteor.startup ->

  Router.map ->
    @route 'apiListInstances',
      where: 'server'
      path: '/api/v1/instances/:app/:version'
      action: ->
        check([@params.app, @params.version], [String])
        instNames = Instances.find(project: Settings.findOne().project, "meta.appName": @params.app, "meta.appVersion": @params.version).map (inst) -> inst.name
        @response.writeHead 200, 'Content-Type': 'application/json'
        @response.end EJSON.stringify(instNames)
    @route 'apiStatus',
      where: 'server'
      path: '/api/v1/state/:name'
    .get ->
        check(@params.name, String)
        instance = Instances.findOne project: Settings.findOne().project, name: @params.name
        if instance
          @response.writeHead 200, 'Content-Type': 'application/json'
          @response.end instance.meta.state
        else
          @response.writeHead 404, 'Content-Type': 'application/json'
          @response.end '{"message": "Instance not found"}'
    .put ->
        check(@params.name, String)
        instance = Instances.findOne(project: Settings.findOne().project, name: @params.name) or {}
        updatedInstance = lodash.merge instance, @request.body
        Instances.upsert {project: Settings.findOne().project, name: @params.name}, {$set: _.omit(updatedInstance, '_id')}, (err, result) =>
          console.log err, result
          if err or not result
            @response.writeHead 404, 'Content-Type': 'application/json'
            @response.end '{"message": "Instance not found"}'
          else
            @response.writeHead 200, 'Content-Type': 'application/json'
            @response.end "#{@params.name} state changed to #{updatedInstance}"
    .delete ->
        check(@params.name, String)
        Instances.remove {project: Settings.findOne().project, name: @params.name}, (err, result) =>
          console.log err, result
          if err or not result
            @response.writeHead 404, 'Content-Type': 'application/json'
            @response.end '{"message": "Instance not found"}'
          else
            @response.writeHead 200, 'Content-Type': 'application/json'
            @response.end "#{@params.name} removed"
