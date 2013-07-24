kite         = KD.getSingleton "kiteController"
{nickname}   = KD.whoami().profile
appStorage = new AppStorage "rails-installer", "1.0"

class RailsInstallPane extends RailsPane
  constructor:(options={}, data)->

    super options, data

    @form = new KDFormViewWithFields
      callback              : @bound "installRails"
      buttons               :
        install             :
          title             : "Create Rails instance"
          style             : "cupid-green"
          type              : "submit"
          loader            :
            color           : "#444444"
            diameter        : 12
      fields                :
        name                :
          label             : "Name of Rails App:"
          name              : "name"
          placeholder       : "type a name for your app..."
          defaultValue      : "myRailsInstance"
          validate          :
            rules           :
              required      : "yes"
              regExp        : /(^$)|(^[a-z\d]+([a-z\d]+)*$)/i
            messages        :
              required      : "a name for your rails app is required!"
          nextElement       :
            timestamp       :
              name          : "timestamp"
              type          : "hidden"
              defaultValue  : Date.now()
        domain              :
          label             : "Domain :"
          name              : "domain"
          itemClass         : KDSelectBox
          defaultValue      : "#{nickname}.kd.io"
        rubyversion       :
          label             : "Ruby Version :"
          name              : "rubyversion"
          itemClass         : KDSelectBox
          defaultValue      : "2.0.0"
        railsversion       :
          label             : "Rails Version :"
          name              : "railsversion"
          itemClass         : KDSelectBox
          defaultValue      : "4.0.0"


    @form.on "FormValidationFailed", => @form.buttons["Create Rails instance"].hideLoader()

    vmc = KD.getSingleton 'vmController'

    vmc.fetchVMs (err, vms)=>
      if err then console.log err
      else
        vms.forEach (vm) =>
          vmc.fetchVMDomains vm, (err, domains) =>
            newSelectOptions = []
            usableDomains = [domain for domain in domains when not /^(vm|shared)-[0-9]/.test domain].first
            usableDomains.forEach (domain) =>
              newSelectOptions.push {title : domain, value : domain}

            {domain} = @form.inputs
            domain.setSelectOptions newSelectOptions


    # Populate ruby version
    newRubyOptions = []
    newRubyOptions.push {title : "2.0.0 (stable)", value : "2.0.0"}
    newRubyOptions.push {title : "1.9.3", value : "1.9.3"}
    {rubyversion} = @form.inputs
    rubyversion.setSelectOptions newRubyOptions

    # Populate rails version
    newRailsOptions = []
    newRailsOptions.push {title : "4.0.0 (stable)", value : "4.0.0"}
    newRailsOptions.push {title : "3.2.14", value : "3.2.14"}

    {railsversion} = @form.inputs
    railsversion.setSelectOptions newRailsOptions

    @terminal = new KDView
      cssClass: "terminal"
    @terminal.$().css
      width: "100%"

    @webterm = new WebTermView
      delegate: @terminal
      cssClass: "webterm"

    @webterm.on "WebTermConnected", (remote)=>
      @remote = remote

    # webterm crashes when its hidden, so we hide it using height: 0
    @terminalWrapper = new KDView
    @terminalWrapper.$().css "height", 0
    @terminalWrapper.addSubView @webterm

    @terminal.addSubView @terminalWrapper


  checkPath: (name, callback)->
    instancesDir = "railsapp"

    kite.run "[ -d /home/#{nickname}/#{instancesDir}/#{name} ] && echo 'These directories exist'"
    , (err, response)->
      if response
        console.log "You have already a Rails instance with the name \"#{name}\". Please delete it or choose another path"
      callback? err, response

  hideTerminal: ->
    @terminalWrapper.getDelegate().$().animate height: 0, 100

  showTerminal: (callback)->
    @terminalWrapper.getDelegate().$().animate height: @terminal.height, 100, =>
      @webterm.$().click()
      callback?()

  showInstallFail: ->
    new KDNotificationView
        title     : "Rails instance exists already. Please delete it or choose another name"
        duration  : 3000

  installRails: =>
    @showTerminal()
    domain = @form.inputs.domain.getValue()
    name = @form.inputs.name.getValue()
    rubyversion = @form.inputs.rubyversion.getValue()
    railsversion = @form.inputs.railsversion.getValue()
    timestamp = parseInt @form.inputs.timestamp.getValue(), 10

    @checkPath name, (err, response)=>
      if err # means there is no such folder
        console.log "Starting install with formData", @form

        #If you change it, grep the source file because this variable is used
        instancesDir = "railsapp"

        command = "[ -d \"#{instancesDir}\" ] || mkdir '#{instancesDir}' && \
                   \curl -L https://get.rvm.io | bash  && \
                   echo 'source ~/.rvm/scripts/rvm' >> ~/.bash_aliases && source ~/.bash_aliases && \
                   echo '[[ -s \"$HOME/.rvm/scripts/rvm\" ]] && source \"$HOME/.rvm/scripts/rvm\"' >> ~/.bashrc && \
                   rvm install #{rubyversion} && \
                   rvm use #{rubyversion} && \
                   rvm rubygems current && \
                   rvm gemset create rails#{railsversion} && \
                   rvm gemset use rails#{railsversion} && \
                   gem install rails --no-ri --no-rdoc --version=#{railsversion} && \
                   rails new '#{instancesDir}/#{name}' && \
                   echo '*** -> Installation successfull at: \"~/#{instancesDir}/#{name}\". Rails is ready with version #{railsversion}, using Ruby #{rubyversion}'\n"


        formData = {timestamp: timestamp, domain: domain, name: name,rubyversion: rubyversion, railsversion: railsversion}
        @remote.input command
        @form.buttons.install.hideLoader()
        appStorage.fetchValue 'blogs', (blogs)->
          blogs or= []
          blogs.push formData
          appStorage.setValue "blogs", blogs

        @emit "RailsInstalled", formData

      else # there is a folder on the same path so fail.
        @form.buttons.install.hideLoader()
        @showInstallFail()


  pistachio:->
    """
    {{> this.form}}
    <br>
    <i>note: your sudo password is your koding password</i>
    <br>
    {{> this.terminal}}
    """




