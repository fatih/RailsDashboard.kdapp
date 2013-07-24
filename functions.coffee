#
# App Globals
#

kc         = KD.getSingleton "kiteController"
fc         = KD.getSingleton "finderController"
tc         = fc.treeController
{nickname} = KD.whoami().profile
appStorage = new AppStorage "rails-installer", "1.0"

#
# App Functions
#

showInstallSuccess = -> 
    new KDNotificationView
        title     : "Rails instance successfull installed"
        cssClass  : "success"
        duration  : 3000
        
        
parseOutput = (res, err = no)->
  res = "<br><cite style='color:red'>[ERROR] #{res}</cite><br><br><br>" if err
  {output} = split
  output.setPartial res
  output.utils.wait 100, ->
    output.scrollTo
      top      : output.getScrollHeight()
      duration : 100

checkPath = (formData, callback)->

  {name, domain} = formData
  instancesDir = "railsapp"

  kc.run "[ -d /home/#{nickname}/#{instancesDir}/#{name} ] && echo 'These directories exist'"
  , (err, response)->
    if response
      parseOutput "You have already a Rails instance with the name \"#{name}\". Please delete it or choose another path", yes
    callback? err, response


      
String::capitalize = ->
    return this.substr(0, 1).toUpperCase() + this.substr(1)

installRails = (formData)->
  
  console.log "Starting install with formDAta", formData

  {name, domain, railsversion, rubyversion} = formData

  path = "/"
  #If you change it, grep the source file because this variable is used
  instancesDir = "railsapp"
  tmpAppDir = "#{instancesDir}/tmpFilesRails"
               
  commands = []
  
  # create dirs to rails applications
  commands.push "mkdir -p '#{tmpAppDir}"
  commands.push "[ -d \"#{instancesDir}\" ] || mkdir '#{instancesDir}'"

  # install rails and build dependencies
  commands.push "sudo gem install rails"
  commands.push "sudo apt-get install libsqlite3-dev"
  
  # create new instance
  commands.push "rails new '#{instancesDir}/#{name}'"
  
              
  # Disable color output for rails commands. This supress the fcking color codes that comes with the rails command
  # which doesnt have any fcking --no-color option. Thank you rails!
  # Line 35 is empty, thus a hacky but good option
  #commands.push "sed -e '35s/$/    config.colorize_logging = false/' -i #{instancesDir}/#{name}/config/application.rb"


  # Run commands in correct order if one fails do not continue
  runInQueue = (cmds, index)=>
    command  = cmds[index]
    if cmds.length == index or not command
      showInstallSuccess()
      parseOutput "<br>#############"
      parseOutput "<br>Rails instance path				: /Users/#{nickname}/#{instancesDir}/#{name}"
      parseOutput "<br>"
      parseOutput "<br>#############<br>"
      parseOutput "<br><br><br>"
      
      # It's gonna be le{wait for it....}gendary.
      KD.utils.wait 1000, ->
        appManager.openFileWithApplication "https://#{nickname}.kd.io/", "Viewer"
      
    else
      parseOutput "$ #{command}<br/>"
      kc.run command, (err, res)=>
        if err
          parseOutput err.message, yes
          split.railsApp.buttonGroup.buttons["Create a new Rails App"].hideLoader()
          KD.utils.wait 10000, ->
            split.resizePanel 0, 1
        else
          parseOutput res + '<br/>'
          runInQueue cmds, index + 1
       
  # There you go brother ...
  runInQueue commands, 0

