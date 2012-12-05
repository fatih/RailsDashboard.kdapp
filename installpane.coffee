class RailsInstallPane extends RailsPane

  constructor:->

    super

    @form = new KDFormViewWithFields
      callback              : @submit.bind(@)
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
          defaultValue      : "#{nickname}.koding.com"
        railsversion       :
          label             : "Rails Version :"
          name              : "railsversion"
          itemClass         : KDSelectBox
          defaultValue      : "3.2.9"
        rubyversion       :
          label             : "Ruby Version :"
          name              : "rubyversion"
          itemClass         : KDSelectBox
          defaultValue      : "1.9.3"

    @form.on "FormValidationFailed", => @form.buttons["Create Rails instance"].hideLoader()

    domainsPath = "/Users/#{nickname}/Sites"

    kc.run "ls #{domainsPath} -lpva"
    , (err, response)=>
      if err then warn err
      else
        files = FSHelper.parseLsOutput [domainsPath], response
        newSelectOptions = []

        files.forEach (domain)->
          newSelectOptions.push {title : domain.name, value : domain.name}

        {domain} = @form.inputs
        domain.setSelectOptions newSelectOptions
        
    # Populate rails version
    newRailsOptions = []
    newRailsOptions.push {title : "3.2.9 (stable)", value : "3.2.9"}
    
    {railsversion} = @form.inputs
    railsversion.setSelectOptions newRailsOptions
    
    # Populate ruby version
    newRubyOptions = []
    newRubyOptions.push {title : "1.9.3 (stable)", value : "1.9.3"}
    newRubyOptions.push {title : "1.8.7", value : "1.8.7"}
    
    {rubyversion} = @form.inputs
    rubyversion.setSelectOptions newRubyOptions
    
  # Install 
  submit:(formData)=>
   
    {domain, name, railsversion, rubyversion} = formData
    formData.timestamp = parseInt formData.timestamp, 10
    formData.fullPath = "#{domain}/website/"
    formData.setupFcgi = on # Enable it for us ..
    formData.currentFcgiName = name  #For now it's itself

    # .. but disable setupFcgi for all other instances
    appStorage.fetchValue 'blogs', (blogs)->
      console.log "App Storage Fetching"
      
      if blogs? and blogs.length > 0
        console.log "There are some instances.."
        console.log "App Storage Instances", blogs
        for instance, i in blogs
          console.log "Instance:", instance
          blogs[i].setupFcgi = off
          blogs[i].previousFcgiName = instance.currentFcgiName
          formData.previousFcgiName = instance.currentFcgiName
                    
          blogs[i].currentFcgiName = name
        console.log "App Storage Instances (modified)", blogs  
        appStorage.setValue "blogs", blogs
      else
        console.log "There are no instances. Nothing to do."
        formData.previousFcgiName = name  #For now it's itself
        
        
    failCb = =>
      @form.buttons["Create Rails instance"].hideLoader()
      @utils.wait 5000, -> split.resizePanel 0, 1

    successCb = =>
      @emit "RailsBegin", formData
      installRails formData, (timestamp)=>
        @emit "RailsInstalled", formData
        @form.buttons["Create Rails instance"].hideLoader()

    message = """
              <pre>
              There are files in your domain root which conflicts with Rails Dashboard. If you continue Rails Dashboard will override them.
              
              Do you want to proceed?
              </pre>
              """
    warning = """
              <p class='modalformline' style='color:gray'>
              Note:  These files are <strong>dispatch.fcgi</strong> and <strong>.htaccess</strong>. You can backup these files and use them later again
              </p>
              """
    warnHomePath = =>
        modalHome = new KDModalView
            title       : "It seems you're using FastCGI for something else."
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
              Continue     :
                style      : "modal-clean-gray"
                loader     :
                  color    : "#ffffff"
                  diameter : 16
                callback   : =>
                    split.resizePanel 250, 0
                    checkPath formData, (err, response) =>
                        console.log arguments
                        modalHome.buttons.Continue.hideLoader()
                        modalHome.destroy()
                        if err # means there is no such folder
                            console.log "Calling success from warnHomePath"
                            successCb()
                        else # there is a folder on the same path so fail.
                            failCb()
              No           :
                title      : "No thanks"
                style      : "modal-clean-red"
                loader     :
                  color    : "#ffffff"
                  diameter : 16
                callback   : =>
                    console.log "No Clicked"
                    modalHome.buttons.No.hideLoader()
                    modalHome.destroy()
                    failCb()

    checkFastCgi formData, (err, response)=>
        console.log "checkFastCgi"
        if err
            split.resizePanel 250, 0
            # means there is no dispatch and htaccess file
            # now check for path
            checkPath formData, (err, response)=>
                console.log arguments
                if err # means there is no such folder
                    console.log "Calling success from checkFastCgi"
                    successCb()
                else # there is a folder on the same path so fail.
                    failCb()
        else
            warnHomePath()
            @form.buttons["Create Rails instance"].hideLoader()


  pistachio:-> "{{> @form}}"
