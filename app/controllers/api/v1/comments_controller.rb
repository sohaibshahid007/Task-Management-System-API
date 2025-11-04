class Api::V1::CommentsController < Api::BaseController
  before_action :set_task, except: [ :destroy ]
  before_action :set_comment, only: [ :destroy ]

  def index
    return unless @task
    comments = @task.comments.includes(:user)
    render json: CommentSerializer.new(comments).serializable_hash
  end

  def create
    return unless @task

    unless params[:content].present?
      return render_bad_request(
        message: I18n.t("comments.content_required"),
        details: { parameter: "content" }
      )
    end

    comment = @task.comments.build(comment_params.merge(user: current_user))

    if comment.save
      render json: CommentSerializer.new(comment).serializable_hash, status: :created
    else
      render_validation_error(
        message: I18n.t("comments.creation_failed"),
        errors: comment.errors.full_messages
      )
    end
  rescue StandardError => e
    Rails.logger.error "Comment creation error: #{e.class} - #{e.message}"
    render_error(
      code: "INTERNAL_SERVER_ERROR",
      message: I18n.t("errors.unexpected_error"),
      details: {},
      status: :internal_server_error
    )
  end

  def destroy
    return unless @task && @comment

    if @comment.user_id == current_user.id || @task.creator_id == current_user.id || current_user.admin?
      @comment.destroy
      render json: { message: I18n.t("comments.deleted_successfully") }, status: :ok
    else
      render_unauthorized
    end
  end

  private

  def set_task
    unless params[:task_id].present?
      return render_bad_request(
        message: I18n.t("validations.task_id_required"),
        details: { parameter: "task_id" }
      )
    end

    @task = Task.find_by(id: params[:task_id])
    unless @task
      render_not_found(resource: "Task")
      false
    end
  end

  def set_comment
    unless params[:id].present?
      return render_bad_request(
        message: I18n.t("comments.id_required"),
        details: { parameter: "id" }
      )
    end

    if @task
      @comment = @task.comments.find_by(id: params[:id])
    else
      @comment = Comment.find_by(id: params[:id])
      @task = @comment&.task if @comment
    end

    unless @comment
      render_not_found(resource: "Comment")
      false
    end
  end

  def comment_params
    params.permit(:content)
  end
end
