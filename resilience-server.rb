require 'sinatra/base'
require 'mongo'
require 'json'
require "rexml/document"
require 'time'
require 'date'
require 'benchmark'
require 'securerandom'
require 'geocoder'

include Mongo

# This is an implementation of the Open311 GeoReport v2 specification. See http://wiki.open311.org/GeoReport_v2.
# We are only supporting JSON responses for the moment.
#
# Start with rackup -p 4567
# Uses the config.ru file
class App < Sinatra::Base

  @@service_defs = Array.new
  @@service_defs << {"service_code" => "001", "service_name" => "Road Blockage", "description" => "A road has been blocked.", "metadata" => false, "type" => "realtime", "keywords" => "", "group" => "Loss/Damage"}
  @@service_defs << {"service_code" => "002", "service_name" => "Dwelling Damage", "description" => "A dwelling has been damaged.", "metadata" => false, "type" => "realtime", "keywords" => "", "group" => "Loss/Damage"}
  @@service_defs << {"service_code" => "003", "service_name" => "Outbuilding Damage", "description" => "An outbuilding has been damaged.", "metadata" => false, "type" => "realtime", "keywords" => "", "group" => "Loss/Damage"}
  @@service_defs << {"service_code" => "004", "service_name" => "Fencing Damage", "description" => "A fence has been damaged.", "metadata" => false, "type" => "realtime", "keywords" => "", "group" => "Loss/Damage"}
  @@service_defs << {"service_code" => "005", "service_name" => "Driveway Blockage", "description" => "A driveway has been blocked.", "metadata" => false, "type" => "realtime", "keywords" => "", "group" => "Loss/Damage"}
  @@service_defs << {"service_code" => "006", "service_name" => "Vehicle Damage", "description" => "A vehicle has been damaged.", "metadata" => false, "type" => "realtime", "keywords" => "", "group" => "Loss/Damage"}
  @@service_defs << {"service_code" => "007", "service_name" => "Crop Damage/Loss", "description" => "A crop has been lost or damaged.", "metadata" => false, "type" => "realtime", "keywords" => "", "group" => "Loss/Damage"}
  @@service_defs << {"service_code" => "008", "service_name" => "Public Building Damage", "description" => "A public building has been damaged.", "metadata" => false, "type" => "realtime", "keywords" => "", "group" => "Loss/Damage"}
  @@service_defs << {"service_code" => "009", "service_name" => "Commercial Building Damage", "description" => "A commercial building has been damaged.", "metadata" => false, "type" => "realtime", "keywords" => "", "group" => "Loss/Damage"}
  @@service_defs << {"service_code" => "010", "service_name" => "Infrastructure Damage", "description" => "Public infrastructure has been damaged.", "metadata" => false, "type" => "realtime", "keywords" => "", "group" => "Loss/Damage"}
  @@service_defs << {"service_code" => "011", "service_name" => "Contents Damage", "description" => "A building's contents have been damaged.", "metadata" => false, "type" => "realtime", "keywords" => "", "group" => "Loss/Damage"}
  @@service_defs << {"service_code" => "012", "service_name" => "Hazard", "description" => "A situation that may cause property to be damaged or people to be injured.", "metadata" => false, "type" => "realtime", "keywords" => "", "group" => "Hazard/Risk"}
  
  @@PAGE_SIZE = 10
  
  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? and @auth.basic? and @auth.credentials and (@auth.credentials == ['ios', 'xwhTJhJQVgaKP5zuxBloVXa8ieOQEtKv'] || @auth.credentials == ['android', 'oeiWMK4jXXbOmDXFj7fVlcKMiExQfeEG'])
  end

  # GET Service List
  # For now, we don't need to support multiple jurisdictions
  # curl -i -H "Accept: application/json" -X GET http://localhost:4567/services.json
  get '/services.?:format?' do
    content_type 'application/json', :charset => 'utf-8'
    # Construct the list of services
    errors = Array.new
    if (params[:format] != "json")
      errors << {"code" => 400, "description" => 'format not supported'}
    end
    if (errors.count == 0)
      response.body = @@service_defs.to_json
    else
      # render the errors as JSON, using the first error code as the HTTP error code
      status errors[0]["code"]
      response.body = errors.to_json
    end
  end

  def isValidServiceCode?(service_code)
    found = false
    @@service_defs.each do |d|
      if (service_code == d["service_code"])
        found = true
        break
      end
    end
    return found
  end

  # GET Service Definition
  # Not implemented - no services have metadata for the moment
  get '/services/:service_code.?:format?' do
    status 400
    errors = Array.new
    errors << {"code" => 400, "description" => 'method not supported'}
    response.body = errors.to_json
  end

  # POST Service Request
  # curl -i -H "Accept: application/json" -X POST -d "service_code=001&lat=37.76524078&long=-122.4212043&address_string=1234+5th+street&email=smit333%40sfgov.edu&device_id=tt222111&account_id=123456&first_name=john&last_name=smith&phone=111111111&description=A+large+sinkhole+is+destroying+the+street&media_url=http%3A%2F%2Ffarm3.static.flickr.com%2F2002%2F2212426634_5ed477a060.jpg" http://localhost:4567/requests.json
  post '/requests.?:format?' do
    protected!
    content_type 'application/json', :charset => 'utf-8'
    # check for mandatory parameters...
    # jurisdiction_id is not required for this implementation
    # attribute is not required for these services
    # lat/long are required for this implementation
    errors = Array.new
    if (params[:format] != "json")
      errors << {"code" => 400, "description" => 'format not supported'}
    end
    if (params["service_code"] == nil)
      errors << {"code" => 400, "description" => 'service_code not provided'}
    elsif (!isValidServiceCode?(params["service_code"]))
      errors << {"code" => 404, "description" => 'service_code not found'}
    end
    if (params["lat"] == nil)
      errors << {"code" => 400, "description" => 'latitude not provided'}
    elsif (params["lat"].to_f < -90.0) || (params["lat"].to_f > 90.0)
      errors << {"code" => 404, "description" => 'latitude out of range'}
    end
    if (params["long"] == nil)
      errors << {"code" => 400, "description" => 'longitude not provided'}
    elsif (params["long"].to_f < -180.0) || (params["long"].to_f > 180.0)
      errors << {"code" => 404, "description" => 'longitude out of range'}
    end
    if (errors.count == 0)
      # make sure we only get valid keys in the optional parameters
      service_request = params.select {|k,v| ["service_code", "lat", "long", "address_string", "address_id", "email", "device_id", "account_id", "first_name", "last_name", "phone", "description", "media_url"].include?(k) }
      # add the service request to the database
      client = MongoClient.new('localhost', 27017)
      db = client["resilience"]
      coll = db.collection("service-requests")
      service_request["address"] = Geocoder.address(params["lat"]+","+params["long"])
      service_request["service_request_id"] = SecureRandom.uuid
      service_request["status"] = "open"
      service_request["requested_datetime"] = Time.now.utc
      service_request["location"] = {"longitude" => service_request["long"].to_f, "latitude" => service_request["lat"].to_f }
      id = coll.insert(service_request)
      # make sure we have an index set up
      coll.ensure_index([["location", Mongo::GEO2D]])
      # render the response
      r = Array.new
      r << {"service_request_id" => service_request["service_request_id"]}
      response.body = r.to_json
      client.close
    else
      # render the errors as JSON, using the first error code as the HTTP error code
      status errors[0]["code"]
      response.body = errors.to_json
    end
  end

  # GET service_request_id from a token
  # Not implemented - tokens are not used in this implementation
  get '/tokens.?:format?' do
    status 400
    errors = Array.new
    errors << {"code" => 400, "description" => 'method not supported'}
    response.body = errors.to_json
  end

  # GET Service Requests
  # curl -i -H "Accept: application/json" -X GET http://localhost:4567/requests.json?service_request_id=a25a8ab9-75ce-4f25-bfd8-158a0da70fe9
  # curl -i -H "Accept: application/json" -X GET -d "service_code=001" http://localhost:4567/requests.json
  # curl -i -H "Accept: application/json" -X GET -d "status=open" http://localhost:4567/requests.json
  # curl -i -H "Accept: application/json" -X GET -d "start_date=2012-12-01T00:00:00Z&end_date=2013-01-01T00:00:00Z" http://localhost:4567/requests.json
  # curl -i -H "Accept: application/json" -X GET -d "lat=37.76524078&long=-122.4212043&radius=50" http://localhost:4567/requests.json
  # curl -i -H "Accept: application/json" -X GET -d "page=2&lat=37.76524078&long=-122.4212043&radius=50" http://localhost:4567/requests.json
  get '/requests.?:format?' do
    content_type 'application/json', :charset => 'utf-8'
    results = Array.new
    errors = Array.new
    if (params[:format] != "json")
      errors << {"code" => 400, "description" => 'format not supported'}
    elsif (params.count == 1) # return everything
      client = MongoClient.new('localhost', 27017)
      db = client["resilience"]
      coll = db.collection("service-requests")
      coll.find().each do |doc|
        results << format_document(doc)
      end
      client.close
    elsif (params["service_request_id"] != nil) # return a particular request ID
      # If service_request_id is provided (which can include a comma-separated list of ids), it overrides all other parameters
      service_request_ids = params["service_request_id"].split(",")
      service_request_ids.uniq.each do |id|
        client = MongoClient.new('localhost', 27017)
        db = client["resilience"]
        coll = db.collection("service-requests")
        doc = coll.find_one({"service_request_id" => id})
        if (doc != nil)
          results << format_document(doc)
        else
          errors << {"code" => 404, "description" => "service_request_id not found: #{id}"}
        end
        client.close
      end
    else
      search_criteria = Hash.new
      # Handle service_code
      if (params["service_code"] != nil) # filter by service code
        if (isValidServiceCode?(params["service_code"]))
          service_codes = params["service_code"].split(",")
          search_criteria["service_code"] = {"$in" => service_codes}
        else
          errors << {"code" => 404, "description" => "service_code not found: #{params["service_code"]}"}
        end
      end
      # Handle date ranges
      # We could get:
      #   start_date, nil - from start_date to today (1)
      #   nil, end_date - for the 90 days up to end_date (2)
      #   start_date, end_date - from start_date to end_date (3)
      # ... and error if the date span is greater than 90 days
      if (params["start_date"] != nil) || (params["end_date"] != nil) # filter by date
        if (params["start_date"] == nil)  # case (2)
          end_date = Time.parse(params["end_date"])
          start_date = (end_date.to_date - 89).to_time.utc
        else
          if (params["end_date"] == nil)  # case (1)
            start_date = Time.parse(params["start_date"])
            end_date = Time.now.utc
          else  # case (3)
            start_date = Time.parse(params["start_date"])
            end_date = Time.parse(params["end_date"])
          end
        end
        if ((end_date.to_date - start_date.to_date).to_i > 90)
          # error
          errors << {"code" => 400, "description" => "date range spans more than 90 days"}
        else
          # add the date range to the search criteria
          search_criteria["requested_datetime"] = {"$gte" => start_date, "$lt" => end_date}
        end
      end
      # Handle status
      if (params["status"] != nil) # filter by status
        statuses = params["status"].split(",")
        search_criteria["status"] = {"$in" => statuses}
      end
      # Handle location
      if (params["lat"] != nil) && (params["long"] != nil) && (params["radius"] != nil) # filter by location
        if (params["lat"].to_f < -90.0) || (params["lat"].to_f > 90.0)
          errors << {"code" => 404, "description" => 'latitude out of range'}
        end
        if (params["long"].to_f < -180.0) || (params["long"].to_f > 180.0)
          errors << {"code" => 404, "description" => 'longitude out of range'}
        end
        latitude = params["lat"].to_f
        longitude = params["long"].to_f
        location = [longitude, latitude]
        radius = params["radius"].to_f
        # Find items within the radius, sorted by proximity to the centre
        search_criteria["location"] = {"$nearSphere" => location, "$maxDistance" => radius.fdiv(6369)}  # 1 km = 1/6369 radians
      end
      # Perform the search
      if (errors.count == 0)
        client = MongoClient.new('localhost', 27017)
        db = client["resilience"]
        coll = db.collection("service-requests")
        puts "criteria: #{search_criteria}"
        coll.find(search_criteria).each do |doc|
          results << format_document(doc)
          # Handle page number by stripping out unwanted results
          if (params["page"].to_i > 0)
            page = params["page"].to_i
            trimmed_results = results[(page-1)*@@PAGE_SIZE,@@PAGE_SIZE]
            if trimmed_results == nil
              results = []
            else
              results = trimmed_results
            end
          end
        end
        client.close
      end
    end
    # Render the response
    if (errors.count == 0)
      response.body = results.to_json
    else
      # render the errors as JSON, using the first error code as the HTTP error code
      status errors[0]["code"]
      response.body = errors.to_json
    end
  end

  def format_document(doc)
    service_request = doc.select {|k,v| ["service_request_id", "status", "status_notes", "service_code", "description", "requested_datetime", "updated_datetime", "address", "address_id", "zipcode", "lat", "long", "media_url"].include?(k) }
    # look up the service name for the service code
    service_request["service_name"] = @@service_defs[@@service_defs.index{|x| x["service_code"] == service_request["service_code"]}]["service_name"]
    # convert the timestamp to the right format
    service_request["requested_datetime"] = service_request["requested_datetime"].strftime("%Y-%m-%dT%H:%M:%SZ")
    return service_request
  end

  # GET Service Request
  # curl -i -H "Accept: application/json" -X GET http://localhost:4567/requests/395e130d-909b-4236-a94c-a91c4e13b323.json
  get '/requests/:service_request_id.json' do
    content_type 'application/json', :charset => 'utf-8'
    results = Array.new
    errors = Array.new
    if (params[:service_request_id] != nil)
      client = MongoClient.new('localhost', 27017)
      db = client["resilience"]
      coll = db.collection("service-requests")
      doc = coll.find_one({"service_request_id" => params[:service_request_id]})
      if (doc != nil)
        results << format_document(doc)
      else
        errors << {"code" => 404, "description" => "service_request_id not found: #{params[:service_request_id]}"}
      end
      client.close
    end
    if (errors.count == 0)
      response.body = results.to_json
    else
      # render the errors as JSON, using the first error code as the HTTP error code
      status errors[0]["code"]
      response.body = errors.to_json
    end
  end

  # PUT Service Request
  # curl -i -H "Accept: application/json" -X PUT -d "status=open" http://localhost:4567/requests/395e130d-909b-4236-a94c-a91c4e13b323.json
  # curl -i -H "Accept: application/json" -X PUT -d "status=closed" http://localhost:4567/requests/395e130d-909b-4236-a94c-a91c4e13b323.json
  put '/requests/:service_request_id.json' do
    protected!
    content_type 'application/json', :charset => 'utf-8'
    results = Array.new
    errors = Array.new
    if (params["status"] == "open") || (params["status"] == "closed")
      status = params["status"]
      # find the service request and update it
      client = MongoClient.new('localhost', 27017)
      db = client["resilience"]
      coll = db.collection("service-requests")
      doc = coll.find_one({"service_request_id" => params[:service_request_id]})
      if (doc != nil)
        coll.update({"service_request_id" => params[:service_request_id]}, {"$set" => {"status" => status}})
        results << {"service_request_id" => params[:service_request_id]}
      else
        errors << {"code" => 404, "description" => "service_request_id not found: #{params[:service_request_id]}"}
      end
      client.close
    else
      errors << {"code" => 404, "description" => "invalid status code: #{params["status"]}"}
    end
    if (errors.count == 0)
      response.body = results.to_json
    else
      # render the errors as JSON, using the first error code as the HTTP error code
      status errors[0]["code"]
      response.body = errors.to_json
    end
  end

  # curl -i -H "Accept: application/json" -H "Content-Type:application/json" -d '{"comment":"What an awesome app! You guys rock!", "email": "somedude@here.com"}' http://localhost:9292/feedback.json
  post '/feedback.?:format?' do
    protected!
    content_type 'application/json', :charset => 'utf-8'
    feedback = JSON.parse(request.body.read)
    client = MongoClient.new('localhost', 27017)
    db = client["resilience"]
    coll = db.collection("feedback")
    if feedback['comment']
      id = coll.insert({ comment: feedback['comment'], email:feedback['email'], agent:request.user_agent })
      status 201
    else
      status 400
    end
    client.close
  end
end
