# discourse-textify

A Discourse plugin that provides a plain text view of topics, stripping out images, media, and interactive elements.

## Features

- **Text-only topic view**: Access any topic as plain text by appending `/text` to the URL
- **Clean output**: Removes images, videos, audio, iframes, embeds, oneboxes, and other media
- **Link preservation**: Converts hyperlinks to readable format with URLs in parentheses
- **Rate limiting**: Configurable rate limits to prevent abuse
- **Anonymous access**: Optional setting to allow non-logged-in users
- **User preference**: Users can enable auto-redirect to text view in their preferences

## Installation

Follow the standard Discourse plugin installation process:

```bash
cd /var/discourse
./launcher enter app
cd /var/www/discourse/plugins
git clone https://github.com/amal/discourse-textify.git
cd /var/www/discourse
RAILS_ENV=production bundle exec rake assets:precompile
```

Then rebuild your container:

```bash
cd /var/discourse
./launcher rebuild app
```

## Usage

To view any topic as plain text, append `/text` to the topic URL:

```
https://your-forum.com/t/topic-slug/123/text
```

Or without the slug:

```
https://your-forum.com/t/123/text
```

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `textify_enabled` | `true` | Enable or disable the plugin |
| `textify_show_button` | `true` | Show the text view button in topic UI |
| `textify_rate_limit_per_hour` | `60` | Maximum text view requests per hour per user (0 = unlimited) |
| `textify_allow_anonymous` | `false` | Allow non-logged-in users to access text view |

## Requirements

- Discourse 2.7.0 or higher

## License

MIT License - see [LICENSE](LICENSE) for details.
