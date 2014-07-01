require 'sinatra/base'

#Contains Sinatra routes that prompt for and the player's name
module Sinatra
  module NameHandler

    #The YARD documentation for the routes

      # @!method get_get_name
      # @overload get '/name'
      # Serves the player name form
      # see {Sinatra::NameHandler#registered} for code

      # @!method post_get_name
      # @overload post '/name'
      #Read the username form

    #Defines the specified routds  
    def self.registered(app)

      # Serves the user name form
      app.get '/get_name' do 
        erb :get_name
      end

      #Read username input
      app.post '/get_name' do
        session['name'] = params['name']
        redirect '/new_game'
      end
    end
  end
  register NameHandler
end
