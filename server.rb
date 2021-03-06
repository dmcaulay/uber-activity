require 'rubygems'
require 'bundler'

Bundler.require
Dotenv.load

require 'sinatra/base'
require 'sinatra/reloader'

require 'helpers'
require 'client'

class UberActivity < Sinatra::Base
  use Rack::Session::Cookie
  use Rack::Flash

  use OmniAuth::Builder do
    provider :uber, ENV['UBER_CLIENT_ID'], ENV['UBER_CLIENT_SECRET']
  end

  configure :development do
    register Sinatra::Reloader
  end

  helpers Uber::Helpers

  get '/' do
    redirect to('/login') unless authorized?
    history = Uber::Client.new(token: session[:token]).history(limit: params[:limit] || 10)

    @history = history.group_by { |t| Time.at(t["start_time"]).strftime("%Y-%m") }

    # TODO: Move this logic to a support module/class.
    if @history.size > 1
      total_w_time = history.inject(0) { |sum, t| sum + (t["request_time"] - t["start_time"]).abs }
      @avg_w_time = (total_w_time / history.size) / 60
      @avg_miles = (history.inject(0) { |sum, t| sum + t["distance"] } / history.size).round(2)
    else
      @avg_w_time = @avg_miles = 0
    end

    erb :index
  end

  get '/login' do
    erb :login
  end

  get '/auth/:provider/callback' do
    omniauth = request.env['omniauth.auth']
    login!(omniauth)
    flash[:notice] = "Welcome back!"
    redirect to("/")
  end

  get "/logout" do
    logout!
    flash[:notice] = "You've been logged out."
    redirect to("/")
  end
end
