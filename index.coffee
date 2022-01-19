fs = require 'fs'
readline = require('readline').createInterface
  input: process.stdin
  output: process.stdout

Trakt = require 'trakt.tv'
trakt = new Trakt require('./api.json')

login = ->
  try
    token = JSON.parse fs.readFileSync 'token.json', encoding: 'utf8'
    await trakt.import_token token
  catch
    poll = await trakt.get_codes()
    console.log "Please log into #{poll.verification_url} with code #{poll.user_code}"
    await trakt.poll_access poll
  token = trakt.export_token()
  fs.writeFileSync 'token.json', JSON.stringify(token), encoding: 'utf8'

lookup = (title) ->
  matches = await trakt.search.text
    type: 'show'
    query: encodeURIComponent title
  return null unless matches.length
  if matches[0].score >= 1000 and (matches.length == 1 or matches[1].score < 500)
    matches[0].show
  else
    console.log "!! #{title} has imperfect matches:"
    for match, i in matches
      console.log "#{i}. #{match.show.title} (#{match.show.year}) https://trakt.tv/shows/#{match.show.ids.slug}"
    choice = await new Promise (done) ->
      readline.question 'Do any of these match? ', done
    choice = parseInt choice
    if isNaN choice
      null
    else
      matches[choice].show

year = 2020  # starting year
months =
  Jan: 0
  Feb: 1
  Mar: 2
  Apr: 3
  May: 4
  Jun: 5
  Jul: 6
  Aug: 7
  Sep: 8
  Oct: 9
  Nov: 10
  Dec: 11

parseFollowshows = ->
  try
    showmap = JSON.parse fs.readFileSync 'showmap.json', encoding: 'utf8'
    for key, value of showmap
      delete showmap[key] unless value?  # force rechecking null's, once
  catch
    showmap = {}
  followshows = fs.readFileSync 'followshows.txt', encoding: 'utf8'
  r = /You (?:followed (.*?)|watched (.*?) - (.*?) \((\d+)x(\d+)\))\.\r?\n(\d+) (\w+)/g
  parsed = while match = r.exec followshows
    [follow, watch, title, season, episode, day, month] = match[1..7]
    month = months[month]
    day = parseInt day
    if not month? or isNaN day
      throw new Error "month=#{month} day=#{day} in #{match[0]}"
    if watch?
      season = parseInt season
      episode = parseInt episode
      if isNaN(season) or isNaN(episode)
        throw new Error "season=#{month} episode=#{day} in #{match[0]}"
    date = new Date year, month, day
    if lastDate? and lastDate < date
      year--
      date = new Date year, month, day
    lastDate = date
    show = follow or watch
    show = show.replace /\s*\([0-9]+\)\s*$/g, '' # remove years at end
    show = show.replace /\s*\(US\)\s*$/g, '' # remove countries
    show = show.trim()
    unless show of showmap
      console.log ">> Looking up show #{show}..."
      showmap[show] = await lookup show
    continue unless showmap[show]?
    {follow, watch, title, season, episode, date, show: showmap[show]}
  fs.writeFileSync 'showmap.json', JSON.stringify(showmap), encoding: 'utf8'
  parsed

makeHistory = (parsed) ->
  shows = {}
  for item in parsed
    continue unless item.watch
    #console.log item
    #continue unless item.show.title == 'The Tomorrow People (US)'
    show = shows[item.show.ids.trakt]
    unless show?
      show = shows[item.show.ids.trakt] = {}
      show.title = item.show.title
      show.year = item.show.year
      show.ids = item.show.ids
      show.seasons = {}
    show.seasons[item.season] ?= {}
    show.seasons[item.season][item.episode] = watched_at: item.date
  for id, show of shows
    show.seasons = for num, eps of show.seasons
      number: parseInt num
      episodes: for num, data of eps
        data.number = parseInt num
        data
    show

removeHistory = (parsed) ->
  shows = makeHistory parsed
  #console.dir (shows), depth: null
  console.log 'REMOVING'
  console.dir (await trakt.sync.history.remove shows: shows), depth: null

addHistory = (parsed) ->
  shows = makeHistory parsed
  #console.dir (shows), depth: null
  console.log 'ADDING'
  console.dir (await trakt.sync.history.add shows: shows), depth: null

makeWatchlist = (parsed) ->
  shows = {}
  for item in parsed
    id = item.show.ids.trakt
    if item.follow
      shows[id] ?= item.show
    else if item.watch  # skip already watched shows
      shows[id] = 'skip'
  shows = (show for id, show of shows when show != 'skip')

removeWatchlist = (parsed) ->
  shows = makeWatchlist parsed
  #console.dir (shows), depth: null
  console.log 'REMOVING WATCHLIST'
  console.dir (await trakt.sync.watchlist.remove shows: shows), depth: null

addWatchlist = (parsed) ->
  shows = makeWatchlist parsed
  #console.dir (shows), depth: null
  console.log 'ADDING WATCHLIST'
  console.dir (await trakt.sync.watchlist.add shows: shows), depth: null

all = ->
  await login()
  parsed = await parseFollowshows()
  console.log parsed
  #await removeHistory parsed
  #await addHistory parsed
  #await removeWatchlist parsed
  #await addWatchlist parsed
  process.exit()

all()
