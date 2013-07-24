class RailsApp extends JView

  constructor:->

    super
    
    @listenWindowResize()
 
    @dashboardTabs = new KDTabView
      hideHandleCloseIcons : yes
      hideHandleContainer  : yes
      cssClass             : "rails-installer-tabs"

    @consoleToggle = new KDToggleButton
      states          : [
        title         : "Console"
        callback      : (callback)->
          @setClass "toggle"
          split.resizePanel 250, 0
          callback null
      ,
        title         : "Console &times;"
        callback      : (callback)->
          @unsetClass "toggle"
          split.resizePanel 0, 1
          callback null
      ]
      
    @buttonGroup = new KDButtonGroupView
      buttons       :
        "Dashboard" :
          cssClass  : "clean-gray toggle"
          callback  : => @dashboardTabs.showPaneByIndex 0
        "Create a new Rails App" :
          cssClass  : "clean-gray"
          loader    :
            color   : "#EBEBEB"
            diameter: 15
          callback  : => 
            @dashboardTabs.showPaneByIndex 1
            @buttonGroup.buttons["Create a new Rails App"].hideLoader()

    @dashboardTabs.on "PaneDidShow", (pane)=>
      if pane.name is "dashboard"
        @buttonGroup.buttonReceivedClick @buttonGroup.buttons.Dashboard
      else
        @buttonGroup.buttonReceivedClick @buttonGroup.buttons["Create a new Rails App"]

  viewAppended:->

    super
    
    @dashboardTabs.addPane dashboard = new RailsDashboardPane
      cssClass : "dashboard"
      name     : "dashboard"

    @dashboardTabs.addPane installPane = new RailsInstallPane
      name     : "install"
      
    @dashboardTabs.showPane dashboard

    installPane.on "RailsBegin", (formdata) =>
      @buttonGroup.buttons["Create a new Rails App"].showLoader()

      #@loaderView.show()
      #@installLoader.show()

    installPane.on "RailsInstalled", (formData)=>
      @buttonGroup.buttons["Create a new Rails App"].hideLoader()
      #@loaderView.hide()
      #@installLoader.hide()
      
      {domain, name} = formData
      instancesDir = "railsapp"
      
      dashboard.reloadListNew formData
      #dashboard.putNewItem formData
      split.resizePanel 0, 1
      @dashboardTabs.showPaneByIndex 0

      console.log "INSTANCE NAME: #{instancesDir}"
      console.log "NAME: #{name}"
      KD.utils.wait 200, ->
        tc.refreshFolder tc.nodes["/Users/#{nickname}"], ->
          KD.utils.wait 200, ->
            tc.refreshFolder tc.nodes["/Users/#{nickname}/#{instancesDir}"], ->
              KD.utils.wait 200, ->
                tc.refreshFolder tc.nodes["/Users/#{nickname}/#{instancesDir}/#{name}"]
                tc.selectNode tc.nodes["/Users/#{nickname}/#{instancesDir}/#{name}"]

        

    @_windowDidResize()

  _windowDidResize:->

    @dashboardTabs.setHeight @getHeight() - @$('>header').height()

  pistachio:->

    """
    <header>
      <figure></figure>
      <article>
        <h3>Rails Dashboard</h3>
        <p>This application installs Rails App instances and setup a server into your home folder.</p>
        <p>You can maintain all your Rails instances via the dashboard and switch between them.</p>
      </article>
      <section>
      {{> @buttonGroup}}
      {{> @consoleToggle}}
      </section>
    </header>
    {{> @dashboardTabs}}
    """

class RailsSplit extends KDSplitView

  constructor:(options, data)->
      

    @output = new KDScrollView
      tagName  : "pre"
      cssClass : "terminal-screen"

    @railsApp = new RailsApp

    options.views = [ @railsApp, @output ]

    super options, data

  viewAppended:->

    super

    @panels[1].setClass "terminal-tab"


class RailsPane extends KDTabPaneView

  viewAppended:->

    @setTemplate @pistachio()
    @template.update()
