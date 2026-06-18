class SimulationJob < ApplicationJob
  queue_as :default

  def perform
    service = SimulationService.new
    probabilities = service.run
    Participant.update_all(win_probability: 0.0)
    probabilities.each do |participant_id, prob|
      Participant.where(id: participant_id).update_all(win_probability: prob)
    end
    cannot_win = service.cannot_win_participants
    Participant.where(id: cannot_win.to_a).update_all(win_probability: -1.0)
  end
end
