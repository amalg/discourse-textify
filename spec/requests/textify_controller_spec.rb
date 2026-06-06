# frozen_string_literal: true

require "rails_helper"

RSpec.describe TextifyController do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }

  before { SiteSetting.textify_enabled = true }

  describe "#show" do
    context "when anonymous access is allowed" do
      before { SiteSetting.textify_allow_anonymous = true }

      # Regression: previously the controller passed request.remote_ip (a String)
      # as RateLimiter's user argument, which crashed RateLimiter#build_key
      # (String has no #id), returning a 500 for every logged-out visitor.
      it "renders the text view for anonymous visitors without crashing" do
        get "/t/#{topic.slug}/#{topic.id}/text"

        expect(response.status).to eq(200)
        expect(response.body).to include(topic.title)
      end

      it "rate limits anonymous visitors by IP" do
        RateLimiter.enable
        RateLimiter.clear_all!
        SiteSetting.textify_rate_limit_per_hour = 1

        get "/t/#{topic.slug}/#{topic.id}/text"
        expect(response.status).to eq(200)

        get "/t/#{topic.slug}/#{topic.id}/text"
        expect(response.status).to eq(429)
      end
    end

    context "when anonymous access is not allowed" do
      before { SiteSetting.textify_allow_anonymous = false }

      it "does not serve the text view to anonymous visitors" do
        get "/t/#{topic.slug}/#{topic.id}/text"

        expect(response.status).not_to eq(200)
      end
    end
  end
end
