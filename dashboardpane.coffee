class RailsDashboardPane extends RailsPane

  constructor:->

    super

    @listController = new KDListViewController
      lastToFirst     : yes
      viewOptions     :
        type          : "rails-blog"
        itemClass     : RailsInstalledAppListItem

    @listWrapper = @listController.getView()

    @notice = new KDCustomHTMLView
      tagName : "p"
      cssClass: "why-u-no"
      partial : "You don't have any Rails instances installed."

    @notice.hide()

    @loader = new KDLoaderView
      size          :
        width       : 60
      cssClass      : "loader"
      loaderOptions :
        color       : "#ccc"
        diameter    : 30
        density     : 30
        range       : 0.4
        speed       : 1
        FPS         : 24

    @listController.getListView().on "RunCommandButtonClicked", (listItemView)=>

      {timestamp, domain, name, rubyversion, railsversion} = listItemView.getData()

      path = ""
      instancesDir = "railsapp"

      modal = new KDModalViewWithForms
        title                   : "Run a command inside your '#{name}' rails instance"
        content                 : "<div class='modalformline'>You can run any rails commands that you run from Terminal</div>"
        overlay                 : yes
        width                   : 600
        height                  : "auto"
        tabs                    :
          navigable             : yes
          forms                 :
            form                :
              buttons           :
                Run             :
                  cssClass      : "modal-clean-gray"
                  loader        :
                    color       : "#444444"
                    diameter    : 12
                  callback      : ->
                    command = modal.modalTabs.forms.form.inputs.Command.getValue()

                    setTimeout ->
                      if modal.modalTabs.forms.form.buttons.Run.loader.active
                        showError()
                        modal.modalTabs.forms.form.buttons.Clear.getCallback()()
                    , 8000

                    kc.run "cd #{instancesDir}/#{name} && #{command} ", (err, res)->
                      showError() if err
                      modal.modalTabs.forms.form.inputs.Output.setValue err or res
                      modal.modalTabs.forms.form.buttons.Run.hideLoader()
                Clear           :
                  cssClass      : "modal-clean-gray"
                  callback      : ->
                    modal.modalTabs.forms.form.inputs.Output.setValue ''
                    modal.modalTabs.forms.form.buttons.Run.hideLoader()

              fields            :
                Command         :
                  label         : "Command:"
                  name          : "command"
                  placeholder   : "Run a rails command like: rails generate controller static index"
                  cssClass      : "command-input"
                Output          :
                  label         : "Output:"
                  type          : "textarea"
                  name          : "output"
                  placeholder   : "The output of command will be here..."
                  cssClass      : "output-screen"

    @listController.getListView().on "SwitchButtonClicked", (listItemView)=>
      
      {timestamp, domain, name, rubyversion, railsversion, setupFcgi, previousFcgiName, currentFcgiName} = listItemView.getData()
      
      path = ""
      userDir = "/Users/#{nickname}/Sites/#{domain}/website/"
      instancesDir = "railsapp"
      
      # These are used with dispatchFile and environment
      switch rubyversion
        when "1.8.7"
          dispatchVersion = "#!/usr/bin/ruby"
        when "1.9.3"
          dispatchVersion = "#!/usr/bin/ruby1.9"
        else console.log "No default version"
        
      if name is currentFcgiName
        appName = previousFcgiName.capitalize()
        name = previousFcgiName
      else
        appName = name.capitalize()
        
      dispatchFile = """
                     #{dispatchVersion}
                     require 'rubygems'
                     Gem.clear_paths
                     require 'fcgi'
                     require '/Users/#{nickname}/#{instancesDir}/#{name}/config/environment'
                     class Rack::PathInfoRewriter
                      def initialize(app)
                        @app = app
                      end
                      def call(env)
                        env.delete('SCRIPT_NAME')
                        parts = env['REQUEST_URI'].split('?')
                        env['PATH_INFO'] = parts[0]
                        env['QUERY_STRING'] = parts[1].to_s
                        @app.call(env)
                      end
                     end
                     
                     Rack::Handler::FastCGI.run  Rack::PathInfoRewriter.new(#{appName}::Application)
				     """
      message = """
                The files dispatch.fcgi and .htaccess will be replaced for the #{name} instance. Your other rails instances will be still functional.
                
                Do you want to proceed?
                """
      modalHome = new KDModalView
        title       : "Setup FastCGI for '#{name}'"
        content        : """
                          <div class='modalformline'>
                            <p>#{message}</p>
                          </div>
                         """
        height         : "auto"
        overlay        : yes
        width          : 500
        buttons        :
          Continue     :
            style      : "modal-clean-gray"
            loader     :
              color    : "#ffffff"
              diameter : 16
            callback   : =>
              modalHome.buttons.Continue.hideLoader()
              modalHome.destroy()
              kc.run {
                method:"uploadFile",
                withArgs:{
                  path: "#{userDir}/dispatch.fcgi",
                  contents:dispatchFile}
                  }, (err)->
                    if err
                      parseOutput err
                    else
                      console.log "File uploaded"
                      kc.run "pgrep dispatch.fcgi && killall dispatch.fcgi" , (err, response)->
                        if err
                          parseOutput err
                        else
                          console.log "FCGI killed"
                          console.log response
              @switchFcgi listItemView
          No           :
            label      : "No thanks"
            style      : "modal-clean-red"
            loader     :
              color    : "#ffffff"
              diameter : 16
            callback   : =>
              console.log "No Clicked"
              modalHome.buttons.No.hideLoader()
              modalHome.destroy()

    @listController.getListView().on "DeleteLinkClicked", (listItemView)=>

      {domain, name} = listItemView.getData()

      path = ""
      userDir = "/Users/#{nickname}/Sites/#{domain}/website/"
      instancesDir = "railsapp"

      message = "<pre>/Users/#{nickname}/#{instancesDir}/#{name}</pre>"
      command = "rm -r '/Users/#{nickname}/#{instancesDir}/#{name}'"
      warning = """<p class='modalformline' style='color:red'>
                     Warning: This will remove everything under this directory
                     </p>"""

      modal = new KDModalView
        title          : "Are you sure want to delete this Rails instance?"
        content        : """
                          <div class='modalformline'>
                            <p>#{message}</p>
                          </div>
                          #{warning}
                         """
        height         : "auto"
        overlay        : yes
        width          : 500
        buttons        :
          Delete       :
            style      : "modal-clean-red"
            loader     :
              color    : "#ffffff"
              diameter : 16
            callback   : =>
              @removeItem listItemView
              split.resizePanel 250, 0
              parseOutput "<br><br>Deleting /Users/#{nickname}/#{instancesDir}/#{name}<br><br>"
              parseOutput command
              kc.run withArgs : {command} , (err, res)=>
                modal.buttons.Delete.hideLoader()
                modal.destroy()
                if err
                  parseOutput err, yes
                  new KDNotificationView
                    title    : "There was an error, you may need to remove it manually!"
                    duration : 3333
                else
                  parseOutput "<br><br>#############"
                  parseOutput "<br>Your rails instance: '#{name}' is successfully deleted."
                  parseOutput "<br>"
                  parseOutput "<br>Note: You can remove manually dispatch.fcgi and .htacces from your root domain."
                  parseOutput "<br>      Be careful these files might be used with other apps or Rails instances."
                  parseOutput "<br>#############<br><br>"
                  tc.refreshFolder tc.nodes["/Users/#{nickname}/#{instancesDir}"]

                @utils.wait 1500, ->
                  split.resizePanel 0, 1

  switchFcgi:(listItemView)->
    
    {name, previousFcgiName, currentFcgiName} = listItemView.getData()
    
    console.log "FCGI for:"
    console.log "Name       :#{name}"
    console.log "Current    :#{currentFcgiName}"
    console.log "Previous   :#{previousFcgiName}"
    appStorage.fetchValue 'blogs', (blogs) =>
      blogs?=[]
      # Disable setupFcgi for all other but blogName
      if blogs.length > 0
        if name is currentFcgiName
          console.log "Revert to old FCGI"
          for instance, i in blogs
            if instance.name is previousFcgiName
              blogs[i].setupFcgi = on
            else
              blogs[i].setupFcgi = off
            # Store current currentName as the previous fcgi for all instances
            blogs[i].currentFcgiName = previousFcgiName
            blogs[i].previousFcgiName = currentFcgiName
        else
          console.log "Switch to new FCGI"
          for instance, i in blogs
            if instance.name is name
              blogs[i].setupFcgi = on
            else
              blogs[i].setupFcgi = off
            
            blogs[i].previousFcgiName = currentFcgiName
            blogs[i].currentFcgiName = name
            
      appStorage.setValue "blogs", blogs, =>
        @listController.replaceAllItems(blogs)
        new KDNotificationView
          title: "Done. That's it!"
   
  reloadListNew:(formData) ->
    console.log "RELOADDING"
    appStorage.fetchStorage (storage)=>
      blogs = appStorage.getValue("blogs") or []
      if blogs.length > 0
        @listController.replaceAllItems(blogs)
        @listController.addItem formData
        @notice.hide()
      else
        @listController.addItem formData
        @notice.hide()
        
        
  removeItem:(listItemView)->
    {name, previousFcgiName, currentFcgiName} = listItemView.getData()

    appStorage.fetchValue 'blogs', (blogs)=>
      if blogs? and blogs.length > 0
        # Iterate over all instance names and find the one we selected
        # After removing break the for loop (because of hoisted "blogs" variable)
        for instance, i in blogs
          if instance.name is name
            blogs.splice(i, 1)
            break
      else
          console.log "There is no blog!"
        
      # Ok now we removed our instance. Now save the other instances back
      appStorage.setValue "blogs", blogs, =>
        if blogs.length is 0
          @listController.removeAllItems()
          @notice.show()
        else
          #Refresh listview
          @listController.replaceAllItems(blogs)

  putNewItem:(formData, resizeSplit = yes)->

    tabs = @getDelegate()
    tabs.showPane @
    @listController.addItem formData
    @notice.hide()
    if resizeSplit
      @utils.wait 1500, -> split.resizePanel 0, 1

  showError = ->
    new KDNotificationView
      title    : "An error occured while running the command"
      type     : "mini"
      cssClass : "error"
      duration : 3000
    
  viewAppended:->

    super

    @loader.show()

    appStorage.fetchStorage (storage)=>
      @loader.hide()
      blogs = appStorage.getValue("blogs") or []
      if blogs.length > 0
        blogs.sort (a, b) -> if a.timestamp < b.timestamp then -1 else 1
        blogs.forEach (item)=> @putNewItem item, no
      else
        @notice.show()

  pistachio:->
    """
    {{> @loader}}
    {{> @notice}}
    {{> @listWrapper}}
    """

class RailsInstalledAppListItem extends KDListItemView

  constructor:(options, data)->

    options.type = "rails-blog"

    super options, data

    if data.setupFcgi
      @switchButton = new KDButtonView
        cssClass   : "rails-button cupid-green clean-gray test-input"
        title      : "Using FastCGI"
        callback   : => @getDelegate().emit "SwitchButtonClicked", @
    else   
      @switchButton = new KDButtonView
        cssClass   : "clean-gray test-input"
        title      : "Setup FastCGI"
        callback   : => @getDelegate().emit "SwitchButtonClicked", @

    @delete = new KDCustomHTMLView
      tagName : "a"
      cssClass: "delete-link"
      title     : "Deneme"
      click   : => @getDelegate().emit "DeleteLinkClicked", @
          
    @runButton = new KDButtonView
      cssClass   : "clean-gray test-input"
      title      : "Run a rails command"
      callback   : => @getDelegate().emit "RunCommandButtonClicked", @
  
  viewAppended:->
    @setTemplate @pistachio()
    @template.update()
    @utils.wait => @setClass "in"
  
  pistachio:->
    {path, timestamp, domain, name, rubyversion, railsversion, currentFcgiName, previousFcgiName} = @getData()
    url = "https://#{domain}/"
    instancesDir = "railsapp"
    {nickname} = KD.whoami().profile
    """
    {{> @delete}}
    <a target='_blank' class='name-link' href='#{url}'> {{#(name)}} </a>
    <div class="instance-block">
        Rails Path: /Users/#{nickname}/#{instancesDir}/{{#(name)}}
        <br>
        Ruby:  {{#(rubyversion)}}   Rails: {{#(railsversion)}}
        <br>
        {{> @runButton}}   {{> @switchButton}}
    </div>
    <time datetime='#{new Date(timestamp)}'>#{$.timeago new Date(timestamp)}</time>
    """
  