class SessionsController < ApplicationController
  respond_to :json
  def index
    respond_with(current_user)
  end

  def create
    user = User.authenticate(session_params[:username], session_params[:password])
    if user
      session[:user_id] = user.id
      respond_with(user)
    else
      render status: 404, json: {}
    end
  end

  def destroy
    id = current_user.id
    session[:user_id] = nil
    logger.debug "=============="+User.find(id).to_s
    respond_with(User.find(id))
  end

  private
  def session_params
    params.permit(:username, :password)
  end
end