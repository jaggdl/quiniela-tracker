class FetchStripePaymentsJob < ApplicationJob
  queue_as :default

  def perform
    StripePaymentFetcher.call
  end
end
