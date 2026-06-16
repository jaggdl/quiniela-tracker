class SimulationJob < ApplicationJob
  queue_as :default

  def perform
    probabilities = SimulationService.new.run
    Participant.update_all(win_probability: 0.0)
    probabilities.each do |participant_id, prob|
      Participant.where(id: participant_id).update_all(win_probability: prob)
    end
  end
end
