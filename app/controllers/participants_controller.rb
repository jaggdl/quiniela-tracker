class ParticipantsController < ApplicationController
  def index
    is_admin_param = params[:is_admin]
    if is_admin_param
      if is_admin_param == "1"
        cookies[:is_admin] = { value: "1", expires: 1.year.from_now }
      else
        cookies.delete(:is_admin)
      end
      redirect_to root_path(sort: params[:sort].presence_in(%w[pts win]))
      return
    end

    @matches = Match.order(:matchday, :match_number)
    @match_results = @matches.index_by(&:id).transform_values(&:result_set?)
    @show_win = cookies[:is_admin].present?
    @sort = params[:sort].presence_in(%w[pts win]) || "pts"
    @sort = "pts" unless @show_win

    participants = Participant.select(:id, :name, :win_probability)
                              .includes(:predictions)
                              .to_a
    pts_rank = participants.sort_by { |p| [-p.total_points, p.name] }
    @rank_by_pts = {}
    pts_rank.each_with_index { |p, i| @rank_by_pts[p.id] = i + 1 }

    @participants = participants.sort_by { |p| sort_value(p) }

    @leader_points = @participants.map(&:total_points).max || 0

    @max_win_prob = @participants.map(&:win_probability).compact.max || 0.0

    @predictions_by_participant = @participants.each_with_object({}) do |participant, hash|
      hash[participant.id] = participant.predictions.index_by(&:match_id)
    end

    StripePaymentFetcher.call if params[:success]
    @payment_messages = PaymentMessage.recent
  end

  private

  def sort_value(p)
    case @sort
    when "win" then [-p.win_probability, p.name]
    else [-p.total_points, p.name]
    end
  end
end
