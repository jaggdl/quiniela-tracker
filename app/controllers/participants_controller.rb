class ParticipantsController < ApplicationController
  def index
    @matches = Match.order(:matchday, :match_number)

    @participants = Participant
      .includes(predictions: :match)
      .sort_by { |p| [-p.total_points, p.name] }

    @leader_points = @participants.first&.total_points || 0

    @predictions_by_participant = @participants.each_with_object({}) do |participant, hash|
      hash[participant.id] = participant.predictions.index_by(&:match_id)
    end
  end
end
