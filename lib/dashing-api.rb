require 'json'
require 'sinatra'
require 'helperFunctions.rb'

functions = HelperFunctions.new

# A noobie way of overriding not_found block for 404
error 404 do
    content_type :json
    { :error => 404, :message => @message }.to_json
end

# Get the current status of the tile
get '/tiles/:id.json' do
    content_type :json
    if data = settings.history[params[:id]]
    	data.split[1]
    else
    	@message = "Host " + params[:id] + "does not exist"
    	404
    end	
end  

# List all widgets
get '/widgets/' do
    content_type :json
    widgets = Array.new()

    Dir.entries(settings.root+'/widgets/').each do |widget|
	if !File.directory? widget 
	    widgets.push widget
	end
    end

    { :widgets => widgets }.to_json
end

# List all dashboards
get '/dashboards/' do
    content_type :json
    dashboards = Array.new()

    # Get the name of the dashboard only. Strip the path
    Dir.entries(settings.root+'/dashboards/').each do |dashboard|
    	dashArray = dashboard.split("/")
	dashboard = dashArray[dashArray.length-1]
	dashboards.push dashboard
    end

    { :dashboards => dashboards }.to_json
end

# Check is a dashboard exists
get '/dashboards/:dashboardName' do
    dashboard = params[:dashboardName]    
    if functions.dashboardExists(dashboard, settings.root)
    	{ :dashboard => dashboard, :message => 'Dashboard ' +dashboard+  ' exists' }.to_json
    else
    	@message = "Dashboard " + dashboard + " does not exist"
	404
    end
end

# Rename a dashboard
put '/dashboards/' do
    request.body.rewind
    body = JSON.parse(request.body.read)
    from = body['from']
    to = body['to']
    
    if functions.checkAuthToken(body, settings.auth_token)
    	if functions.dashboardExists(from, settings.root)
      	    File.rename(settings.root+'/dashboards/'+from+'.erb', settings.root+'/dashboards/'+to+'.erb')
            { :dashboard => :message => 'Dashboard Renamed' }.to_json
      	else
      	    @message = "Dashboard " + from + " does not exist"
      	    404
      	end
    else 
	status 401
      	{ :message => 'Invalid API Key' }.to_json
    end
end

# Delete a dashboard
delete '/dashboards/' do
    request.body.rewind
    body = JSON.parse(request.body.read)
    dashboard = body["dashboard"]
   
    if functions.checkAuthToken(body, settings.auth_token)
        if dashboard != settings.default_dashboard
            if functions.dashboardExists(dashboard, settings.root)
                File.delete(settings.root+'/dashboards/'+dashboard+'.erb')
                { :dashboard => dashboard, :message => 'Dashboard ' +dashboard+ ' deleted' }.to_json
            else
            	@message = "Dashboard " + dashboard + " does not exist"
		404
            end
        else
	    status 401
            { :dashboard => dashboard, :message => 'Cannot delete the main dashboard' }.to_json
        end
    else
	status 401
        { :message => 'Invalid API Key' }.to_json
    end
end

  
# Check if a job script is working
get '/tiles/:id' do
    content_type :json
    hostName = params[:id]
    if settings.history[hostName]
        { :tile => hostName, :message => 'Host' +hostName+ ' has a job script' }.to_json
    else
    	@message = "Host " + hostName + " does not have a job script"
	404
    end
end
  
# Check if a tile exists on a dashboard
get '/tiles/:dashboard/:hosts'  do
    hosts = params[:hosts]
    dashboard = params[:dashboard]
    if functions.dashboardExists(dashboard, settings.root)
        output = functions.tileExists(dashboard, hosts, settings.root)
        if output.empty?
            { :dashboard => dashboard, :tiles => hosts, :message => 'Tiles exists on the dashboard' }.to_json
        else
            @message = "Tiles " +output.join(',')+ "does not exist on the dashboard " +dashboard
	    404
        end
    else
    	@message = "Dashboard " + dashboard + " does not exist"
	404
    end
end


# Replace a tile id on a dashboard
put '/tiles/' do
    request.body.rewind
    body = JSON.parse(request.body.read)
    dashboard = body["dashboard"]
    from = body["from"]
    to = body["to"]
  
    if functions.checkAuthToken(body, settings.auth_token)
        if dashboard != settings.default_dashboard
            if functions.dashboardExists(dashboard)
                output = functions.tileExists(dashboard,from, settings.root)
                if output.empty?
                    File.write(settings.root+"/dashboards/"+dashboard+".erb",File.open(settings.root+"/dashboards/"+dashboard+".erb",&:read).gsub(from,to))
                    { :dashboard => dashboard, :tile => to, :message => 'Tile Renamed' }.to_json
                else
                    @message = "Tile " + from + " does not exist on the dashboard " + dashboard + ". Make sure you have given the correct tile name"
		    404
                end
            else
            	@message = "Dashboard " + dashboard + " does not exist"
		404
            end
        else
	    status 403
            { :dashboard => dashboard, :message => 'Cannot modify the main dashboard' }.to_json
        end
    else
        status 403
        { :message => 'Invalid API Key'}.to_json
    end
end

# Create a new dashboard
post '/dashboards/' do
    request.body.rewind
    body = JSON.parse(request.body.read)
    dashboard = body["dashboard"]

    if functions.checkAuthToken(body, settings.auth_token)
        if !functions.dashboardExists(dashboard, settings.root)
            if functions.createDashboard(body, dashboard, settings.root) 
                dashboardLink = "http://"+functions.getHost()+"/"+dashboard
                { :message => 'Dashboard Created', :dashboardLink => dashboardLink }.to_json
            else
            	{ :message => 'Make sure' }.to_json
            end
        else
	    status 400
            { :dashboard => dashboard, :message => 'Dashboard already exists' }.to_json
        end
    else
	status 403
        { :message => 'Invalid API Key' }.to_json
    end
end


    # Delete a tile
  delete '/widgets/' do
    request.body.rewind
    body = JSON.parse(request.body.read)
    dashboard = body["dashboard"]
    hosts = body["hosts"]

    if functions.checkAuthToken(body, settings.auth_token)
       if dashboard != "blue"
          if functions.dashboardExists(dashboard)
             if output.empty?
                functions.deleteTile(dashboard, hosts)
             else
                "Hosts "+output.join(',')+" are not on the dashboard"
             end
          else
             "Dashboard "+dashboard+" does not exist!"
          end
       else
          "Cant modify the Ops dashboard"
       end
    else
       "Invalid API Key!"
    end
  end
