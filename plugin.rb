# frozen_string_literal: true

# name: discourse-textify
# about: Renders topics as plain text without images, media, or interactive elements
# version: 0.1.0
# authors: Amal
# url: https://github.com/amal/discourse-textify
# required_version: 2.7.0

enabled_site_setting :textify_enabled

register_asset "stylesheets/textify.scss"

# Add plugin views to the view path BEFORE after_initialize
PLUGIN_ROOT = File.dirname(__FILE__)
Rails.application.config.paths["app/views"].unshift(File.join(PLUGIN_ROOT, "app/views"))

after_initialize do
  # Register custom user field for auto-redirect preference
  User.register_custom_field_type("textify_auto_redirect", :boolean)
  register_editable_user_custom_field(:textify_auto_redirect)
  DiscoursePluginRegistry.serialized_current_user_fields << "textify_auto_redirect"

  # Load the controller
  require_relative "app/controllers/textify_controller"

  # Add routes
  Discourse::Application.routes.append do
    get "t/:slug/:topic_id/text" => "textify#show", constraints: { topic_id: /\d+/ }
    get "t/:topic_id/text" => "textify#show", constraints: { topic_id: /\d+/ }
  end

  # Add to serializer so frontend knows if user has preference enabled
  add_to_serializer(:current_user, :textify_auto_redirect) do
    object.custom_fields["textify_auto_redirect"]
  end
end
