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

  kc.run "[ -d /Users/#{nickname}/#{instancesDir}/#{name} ] && echo 'These directories exist'"
  , (err, response)->
    if response
      parseOutput "You have already a Rails instance with the name \"#{name}\". Please delete it or choose another path", yes
    callback? err, response

# Check for home files, warn user
checkFastCgi = (formData, callback)->

  {name, domain} = formData
  kc.run "[ -e /Users/#{nickname}/Sites/#{domain}/website/dispatch.fcgi -o -e /Users/#{nickname}/Sites/#{domain}/website/.htaccess ] && echo 'These files exist'"
  , (err, response)->
    #if response
      #parseOutput "These file exists", yes
    callback? err, response
      
String::capitalize = ->
    return this.substr(0, 1).toUpperCase() + this.substr(1)

installRails = (formData, callback)->

  {name, domain, timestamp, railsversion, rubyversion} = formData

  path = "/"
  userDir   = "/Users/#{nickname}/Sites/#{domain}/website/"
  #If you change it, grep the source file because this variable is used
  instancesDir = "railsapp"
  tmpAppDir = "#{instancesDir}/tmpFilesRails"
  
  # rails uses app name: foo as Foo, thus convert the first letter to upper case
  # we'll use that in some .rb files below
  appName = name.capitalize()
  
  commands = [ "mkdir -p '#{tmpAppDir}'"
               "[ -d \"#{instancesDir}\" ] || mkdir '#{instancesDir}'"
               "rails new '#{instancesDir}/#{name}'"]
               
  # Create it, we will need it later during uploading files
  kc.run "mkdir -p '#{tmpAppDir}'", (err, res)=>
        if err
          parseOutput err, yes
        else
          parseOutput res + '<br/>'

  htaccessFile = """
                 RewriteEngine On
                 RewriteCond %{REQUEST_FILENAME} !-f
                 RewriteRule ^(.*)$ /dispatch.fcgi/$1 [QSA,L]
                 """

  # These are used with dispatchFile and environment
  switch rubyversion
      when "1.8.7"
          dispatchVersion = "#!/usr/bin/ruby"
          environmentVersion = """
                               #ENV['HOME'] ||= `echo ~`.strip
                               #ENV['GEM_PATH'] = File.expand_path('~/.gems') + ":" + '/usr/lib/ruby/gems/1.8'
                               #ENV['GEM_HOME'] = File.expand_path('~/.gems')
                               """
      when "1.9.3"
          dispatchVersion = "#!/usr/bin/ruby1.9"
          environmentVersion = """
                               ENV['HOME'] ||= `echo ~`.strip
                               ENV['GEM_HOME'] = File.expand_path('~/.gems')
                               ENV['GEM_PATH'] = File.expand_path('~/.gems') + ":" + '/opt/ruby19/lib64/ruby/gems/1.9.1'
                               """
      else console.log "No default version"


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
                  
  environmentFile = """
                    # Load the rails application
                    require File.expand_path('../application', __FILE__)
                    
                    #{environmentVersion}
                    
                    # Initialize the rails application
                    #{appName}::Application.initialize!
                    """

  # Create files..
  kc.run {
      method:"uploadFile",
      withArgs:{
          path:"#{tmpAppDir}/htaccess.txt",
          contents:htaccessFile }
          }, (err)-> parseOutput err
          
  kc.run {
      method:"uploadFile",
      withArgs:{
          path: "#{tmpAppDir}/dispatch.fcgi",
          contents:dispatchFile}
          }, (err)-> if err
                        parseOutput err

  kc.run {
      method:"uploadFile",
      withArgs:{
          path:"#{tmpAppDir}/environment.rb",
          contents:environmentFile}
          }, (err)-> if err
                        parseOutput err
          
          
  # Disable color output for rails commands. This supress the fcking color codes that comes with the rails command
  # which doesnt have any fcking --no-color option. Thank you rails!
  # Line 35 is empty, thus a hacky but good option
  commands.push "sed -e '35s/$/    config.colorize_logging = false/' -i #{instancesDir}/#{name}/config/application.rb"

  #Move files
  commands.push  "mv #{tmpAppDir}/dispatch.fcgi  ~/Sites/${USER}.koding.com/website/"
  commands.push  "mv #{tmpAppDir}/htaccess.txt  ~/Sites/${USER}.koding.com/website/.htaccess"
  commands.push  "mv #{tmpAppDir}/environment.rb #{instancesDir}/#{name}/config/"

  #Fcgi needs to be executable
  commands.push  "chmod +x  ~/Sites/${USER}.koding.com/website/dispatch.fcgi"

  # Restart server again
  commands.push  "touch ~/Sites/${USER}.koding.com/website/dispatch.fcgi"

  # Run commands in correct order if one fails do not continue
  runInQueue = (cmds, index)=>
    command  = cmds[index]
    if cmds.length == index or not command
      showInstallSuccess()
      parseOutput "<br>#############"
      parseOutput "<br>Rails instance server setup		: #{userDir}#{path}"
      parseOutput "<br>Rails instance path				: /Users/#{nickname}/#{instancesDir}/#{name}"
      parseOutput "<br>"
      parseOutput "<br>#############<br>"
      parseOutput "<br><br><br>"
      appStorage.fetchValue 'blogs', (blogs)->
        blogs or= []
        blogs.push formData
        appStorage.setValue "blogs", blogs
      callback? formData
      
      # It's gonna be le{wait for it....}gendary.
      KD.utils.wait 1000, ->
        appManager.openFileWithApplication "https://#{nickname}.koding.com/", "Viewer"
      
    else
      parseOutput "$ #{command}<br/>"
      kc.run command, (err, res)=>
        if err
          parseOutput err, yes
        else
          parseOutput res + '<br/>'
          runInQueue cmds, index + 1
       
  # There you go brother ...
  runInQueue commands, 0

