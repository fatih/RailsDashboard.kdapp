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

    @listController.getListView().on "StartTerminal", (listItemView)=>
      {timestamp, domain, name, rubyversion, railsversion} = listItemView.getData()

      instancesDir = "railsapp"
      railsDir = "/home/#{nickname}/#{instancesDir}/#{name}"
      railsCmd = "rvm #{rubyversion}@rails#{railsversion} && cd #{railsDir}"

      modal = new ModalViewWithTerminal
        title   : "Rails Dashboard Terminal"
        width   : 700
        overlay : no
        terminal:
          height: 500
          command: railsCmd
          hidden: no
        content : """
                  <div class='modalformline'>
                    <p>Running from <strong>#{railsDir}</strong>.</p>
                    <p>Using Rails <strong>#{railsversion}</strong> with Ruby <strong>#{rubyversion}</strong></p>
                  </div>
                  """
      modal.on "terminal.event", (data)->
        new KDNotificationView
          title: "Opened successfully"

    @listController.getListView().on "StartRailsServer", (listItemView)=>
      {timestamp, domain, name, rubyversion, railsversion} = listItemView.getData()
      instancesDir = "railsapp"
      railsDir = "/home/#{nickname}/#{instancesDir}/#{name}"
      railsCmd = "rvm #{rubyversion}@rails#{railsversion} && cd #{railsDir} && rails server"

      modal = new ModalViewWithTerminal
        title   : "Starting Rails server"
        width   : 700
        overlay : no
        terminal:
          height: 500
          command: railsCmd
          hidden: no
        content : """
                  <div class='modalformline'>
                    <p>Running from <strong>#{railsDir}</strong>.</p>
                    <p>Using Rails <strong>#{railsversion}</strong> with Ruby <strong>#{rubyversion}</strong></p>
                  </div>
                  """
        buttons :
          Visit:
            title: "open http://#{domain}:3000"
            cssClass: "modal-clean-green"
            callback: =>
              @openInNewTab "http://#{domain}:3000"

      modal.on "terminal.event", (data)->
        new KDNotificationView
          title: "Started successfully!"

    @listController.getListView().on "DeleteLinkClicked", (listItemView)=>
      {domain, name} = listItemView.getData()

      instancesDir = "railsapp"
      message = "<pre>/home/#{nickname}/#{instancesDir}/#{name}</pre>"
      command = "rm -r '/home/#{nickname}/#{instancesDir}/#{name}'"
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
              KD.getSingleton("kiteController").run command, (err, res)=>
                modal.buttons.Delete.hideLoader()
                modal.destroy()
                if err
                  console.log "Deleting Rails Error", err
                  new KDNotificationView
                    title    : "There was an error, you may need to remove it manually!"
                    duration : 3333
                else
                  new KDNotificationView
                    title    : "Your rails instance: '#{name}' is successfully deleted."
                    duration : 3333

  reloadListNew:(formData) ->
    appStorage.fetchStorage (storage)=>
      blogs = appStorage.getValue("blogs") or []
      if blogs.length > 0
        @listController.replaceAllItems(blogs)
        @listController.addItem formData
        @notice.hide()
      else
        @listController.addItem formData
        @notice.hide()


  openInNewTab: (url)->
    link = document.createElement "a"
    link.href = link.target = url
    link.style.display = "none"
    document.body.appendChild link
    link.click()
    link.parentNode.removeChild link

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

  putNewItem:(formData, showTab = yes)->
    if showTab
      tabs = @getDelegate()
      tabs.showPane @
    @listController.addItem formData
    @notice.hide()

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
        blogs.forEach (item)=> @putNewItem item
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

    @terminalButton = new KDButtonView
      cssClass   : "clean-gray test-input"
      title      : "Open Terminal"
      callback   : => @getDelegate().emit "StartTerminal", @

    @serverButton = new KDButtonView
      cssClass   : "rails-button cupid-green clean-gray test-input"
      title      : "Start Rails Server"
      callback   : => @getDelegate().emit "StartRailsServer", @

    @delete = new KDCustomHTMLView
      tagName : "a"
      cssClass: "delete-link"
      title     : "Delete link"
      click   : => @getDelegate().emit "DeleteLinkClicked", @

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
        {{> @terminalButton}}   {{> @serverButton}}
    </div>
    <time datetime='#{new Date(timestamp)}'>#{$.timeago new Date(timestamp)}</time>
    """

