{make_esc} = require 'iced-error'
jsdom = require 'jsdom'
fs = require 'fs'
request = require 'request'
crc32 = require('crc').crc32
mongo = require 'mongoskin'
_ = require 'underscore'
time = require 'time'

global.CONFIG = JSON.parse fs.readFileSync 'config.json'

GPlusAPI = require './lib/api'

api = new GPlusAPI CONFIG.refresh_token,CONFIG.uid

db = mongo.db(CONFIG.mongodb,{w:true})
col_upd = db.collection 'updates'
col_e = db.collection 'edits'

fetch = (gcb)->
    esc = make_esc gcb
    await request
        url:'http://zh.moegirl.org/api.php'
        qs:
            format:'json'
            action:'parse'
            page:'User:萌星空/你知道吗/存档/更新姬版'
            prop:'text'
        method:'GET'
        timeout:10000
        #proxy:'http://127.0.0.1:8888'
        headers:
            'User-Agent':'Node.js'
    ,esc defer(req)

    return gcb req.statusCode if req.statusCode is not 200

    html = ''
    try
        html = JSON.parse(req.body).parse.text['*']
    catch e
        return gcb e

    await jsdom.env html,['jquery.js'],{},esc defer (window)

    $ = window.$
    $('table').remove()
    list = for item in $('li')
        title: $.trim $(item).text().split('——')[0]
        url: 'http://zh.moegirl.org' + $(item).children('a:last').attr('href')
        new: $(item).children('a:last').hasClass('new')
    return gcb null,list


update = (gcb)->
    esc = make_esc gcb
    await request
        url:'http://zh.moegirl.org/api.php?format=json&action=query&list=recentchanges&rcnamespace=0&rctoponly=1'
        method:'GET'
        timeout:10000
        proxy:'http://127.0.0.1:8888'
        headers:
            'User-Agent':'Node.js'
    ,esc defer req

    return gcb req.statusCode if req.statusCode is not 200

    rc = []
    try
        rc = JSON.parse(req.body).query.recentchanges
    catch e
        return gcb e
    rcids = for item in rc
        item.rcid

    await col_e.find({rcid:{'$in':rcids}},{_id:0,rcid:1}).toArray esc defer results

    return gcb 'nothing to post' if rc.length == results.length
    results = _.flatten(results.map((item)->item.rcid))
    item = _.find rc,(item)->item.rcid not in results
    return gcb 'nothing to post' if not item?

    item.url = 'http://zh.moegirl.org/' + item.title
    await api.linkPreview encodeURI(item.url),esc defer embed

    return gcb new Error "Cannot fetch #{item.url} from Google server." if not embed.succeeded

    str = """
          条目： ##{item.title.replace(' ','_')}

          更新了哦！不来看看么？
          传送在此：

          →_→ #{encodeURI(item.url)}
          """

    await api.postPublicActivity str,embed.embedItem[0],esc defer activity

    await col_e.insert {rcid:item.rcid},esc defer()

    return gcb null,activity,item.rcid

question = (gcb)->
    esc = make_esc gcb
    await fetch esc defer list

    hash = []
    for item,i in list
        item.hash = crc32(item.title)
        list[i].hash = item.hash
        hash.push item.hash

    await col_upd.find({hash:{'$in':hash}},{_id:0,hash:1}).toArray esc defer results

    return gcb 'nothing to post' if list.length == results.length
    results = _.flatten(results.map((item)->item.hash))
    item = _.find list,(item)->item.hash not in results
    return gcb 'nothing to post' if not item?

    await api.linkPreview encodeURI(item.url),esc defer embed

    return gcb new Error "Cannot fetch #{item.url} from Google server." if not embed.succeeded

    await api.postPublicActivity item.title,embed.embedItem[0],esc defer activity

    await col_upd.insert item,esc defer()

    return gcb null,activity,item

counter = 1
setInterval ->
    now = new time.Date()
    now.setTimezone('Asia/Shanghai')
    if now.getHours() < 6
        if counter is 4
            update (err,a,rcid)->
                counter = 1
                return require('util').log("[U][ERROR]#{err.message}") if err
                require('util').log("[Q][POSTED]#{a.stream.update[0].updateId}(#{rcid})")
            question (err,a,i)->
                return require('util').log("[Q][ERROR]#{err.message}") if err
                require('util').log("[Q][POSTED]#{a.stream.update[0].updateId}(#{i.hash})")
        else
            counter++
    else
        if counter is 4
            question (err,a,i)->
                counter = 1
                return require('util').log("[Q][ERROR]#{err.message}") if err
                require('util').log("[Q][POSTED]#{a.stream.update[0].updateId}(#{i.hash})")

        update (err,a,rcid)->
            counter = 1
            if err
                setTimeout ->
                    update (err,a,rcid)->
                        return require('util').log("[U][ERROR]#{err.message}") if err
                        require('util').log("[U][POSTED]#{a.stream.update[0].updateId}(#{i.hash})")
                ,300000
                return require('util').log("[U][ERROR]#{err.message}")
            require('util').log("[U][POSTED]#{a.stream.update[0].updateId}(#{rcid})")


    question (err,a,i)->
        return require('util').log("[Q][ERROR]#{err.message}") if err
        require('util').log("[Q][POSTED]#{a.stream.update[0].updateId}(#{i.hash})")

,1200000





