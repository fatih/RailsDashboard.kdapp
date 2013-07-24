class RailsApp extends JView

  constructor:->

    super

    @listenWindowResize()

    @dashboardTabs = new KDTabView
      hideHandleCloseIcons : yes
      hideHandleContainer  : yes
      cssClass             : "rails-installer-tabs"

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

    installPane.on "RailsInstalled", (formData)->
      dashboard.putNewItem formData, no

    @_windowDidResize()

  _windowDidResize:->

    @dashboardTabs.setHeight @getHeight() - @$('>header').height()

  pistachio:->

    """
    <header>
      <figure></figure>
      <article>
        <h3>Rails Dashboard</h3>
        <p>This application installs Rails App instances via RVM easily with one click.</p>
        <p>You can maintain all your Rails instances, start the Rails server and console via the dashboard.</p>
      </article>
      <section>
      {{> @buttonGroup}}
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
