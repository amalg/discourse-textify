import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "textify-init",

  initialize() {
    withPluginApi("1.0.0", (api) => {
      const siteSettings = api.container.lookup("service:site-settings");

      if (!siteSettings.textify_enabled) {
        return;
      }

      // Add text view button to topic footer
      if (siteSettings.textify_show_button) {
        api.registerTopicFooterButton({
          id: "textify-button",
          icon: "file-lines",
          priority: 240,
          title: "textify.button_label",
          label: "textify.button_title",
          classNames: ["textify-button"],
          action() {
            const topic = this.topic;
            if (topic) {
              const textUrl = `/t/${topic.slug}/${topic.id}/text`;
              window.open(textUrl, "_blank");
            }
          },
          displayed() {
            return true;
          },
        });
      }

      // Auto-redirect if user preference is enabled
      api.onPageChange((url) => {
        const currentUser = api.getCurrentUser();

        if (!currentUser) {
          return;
        }

        if (!currentUser.textify_auto_redirect) {
          return;
        }

        // Check if this is a topic URL (but not already a text view)
        const topicMatch = url.match(/^\/t\/[^\/]+\/(\d+)(?:\/(\d+))?$/);
        if (topicMatch && !url.endsWith("/text")) {
          const topicId = topicMatch[1];
          const slug = url.split("/")[2];
          window.location.href = `/t/${slug}/${topicId}/text`;
        }
      });

      // Add custom field to user preferences save
      api.modifyClass("controller:preferences/interface", {
        pluginId: "discourse-textify",

        actions: {
          save() {
            this.get("saveAttrNames").push("custom_fields");
            return this._super(...arguments);
          },
        },
      });
    });
  },
};
