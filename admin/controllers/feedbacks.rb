Resilience::Admin.controllers :feedbacks do
  get :index do
    @title = "Feedbacks"
    @feedbacks = Feedback.all
    render 'feedbacks/index'
  end

  get :new do
    @title = pat(:new_title, :model => 'feedback')
    @feedback = Feedback.new
    render 'feedbacks/new'
  end

  post :create do
    @feedback = Feedback.new(params[:feedback])
    if @feedback.save
      @title = pat(:create_title, :model => "feedback #{@feedback.id}")
      flash[:success] = pat(:create_success, :model => 'Feedback')
      params[:save_and_continue] ? redirect(url(:feedbacks, :index)) : redirect(url(:feedbacks, :edit, :id => @feedback.id))
    else
      @title = pat(:create_title, :model => 'feedback')
      flash.now[:error] = pat(:create_error, :model => 'feedback')
      render 'feedbacks/new'
    end
  end

  get :edit, :with => :id do
    @title = pat(:edit_title, :model => "feedback #{params[:id]}")
    @feedback = Feedback.find(params[:id])
    if @feedback
      render 'feedbacks/edit'
    else
      flash[:warning] = pat(:create_error, :model => 'feedback', :id => "#{params[:id]}")
      halt 404
    end
  end

  put :update, :with => :id do
    @title = pat(:update_title, :model => "feedback #{params[:id]}")
    @feedback = Feedback.find(params[:id])
    if @feedback
      if @feedback.update_attributes(params[:feedback])
        flash[:success] = pat(:update_success, :model => 'Feedback', :id =>  "#{params[:id]}")
        params[:save_and_continue] ?
          redirect(url(:feedbacks, :index)) :
          redirect(url(:feedbacks, :edit, :id => @feedback.id))
      else
        flash.now[:error] = pat(:update_error, :model => 'feedback')
        render 'feedbacks/edit'
      end
    else
      flash[:warning] = pat(:update_warning, :model => 'feedback', :id => "#{params[:id]}")
      halt 404
    end
  end

  delete :destroy, :with => :id do
    @title = "Feedbacks"
    feedback = Feedback.find(params[:id])
    if feedback
      if feedback.destroy
        flash[:success] = pat(:delete_success, :model => 'Feedback', :id => "#{params[:id]}")
      else
        flash[:error] = pat(:delete_error, :model => 'feedback')
      end
      redirect url(:feedbacks, :index)
    else
      flash[:warning] = pat(:delete_warning, :model => 'feedback', :id => "#{params[:id]}")
      halt 404
    end
  end

  delete :destroy_many do
    @title = "Feedbacks"
    unless params[:feedback_ids]
      flash[:error] = pat(:destroy_many_error, :model => 'feedback')
      redirect(url(:feedbacks, :index))
    end
    ids = params[:feedback_ids].split(',').map(&:strip)
    feedbacks = Feedback.find(ids)
    
    if feedbacks.each(&:destroy)
    
      flash[:success] = pat(:destroy_many_success, :model => 'Feedbacks', :ids => "#{ids.to_sentence}")
    end
    redirect url(:feedbacks, :index)
  end
end
