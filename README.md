# followshows -> trakt transfer

This is some basic software to transfer your show-watching history from
followshows.com to trakt.tv.

## 1. Export Followshows History

On followshows.com, click on your name in the top-right and select
"View Profile" (the URL is of the form https://followshows.com/user/xxxxxx).
In the JavaScript console, run the following command to load all history:

```js
setInterval(() => document.getElementById('more-contents').click(),500)
```

Then copy/paste the entire page into a text file `followshows.txt`.

Alternatively, use the following code to output the contents to console, then
copy/paste the console into the text file `followshows.txt`.
(Both formats should work, despite differing slightly.)

```js
document.querySelectorAll('.content').forEach((x) => console.log(x.innerText))
```

## 2. Create Trakt API key

[Create a new app](https://trakt.tv/oauth/applications/new)
for [Trakt.tv's API](https://trakt.docs.apiary.io/).
Create a file `api.json` that looks like this:

```json
{
  "client_id": "xxx",
  "client_secret": "xxx"
}
```

## 3. Run this script

1. `npm install`
2. `npm run convert` (equivalent to `coffee index.coffee`)

In the first run, you will need to authenticate as instructured.
After authenticating once, `token.json` will store a longer-lived token;
delete that file if it expires.

Then you will get a series of questions about which shows are which
(for ambiguous cases).  Just follow the instructions, and enter a blank line
if you don't want to answer about a show.  After a successful run,
your answers to show identification will get saved in `showmap.json`;
remove an entry from there if you want to get asked again about that show.

The code will not do any synchronizing by default.  To do so, you need to
uncomment the final few lines of index.coffee:

```coffee
  #await removeHistory parsed
  #await addHistory parsed
  #await removeWatchlist parsed
  #await addWatchlist parsed
```

You probably want `addHistory` (which copies over all show watching to Trakt
history) and `addWatchlist` (which copies over all followed shows that you
haven't watched any of to the Trakt watchlist).  If something goes wrong,
you can use the corresponding `removeHistory` and `removeWatchlist` to undo
the previous corresponding `add`s, and then re-`add`.
