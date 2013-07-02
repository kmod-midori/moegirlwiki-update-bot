{make_esc} = require 'iced-error'
jsdom = require 'jsdom'
fs = require 'fs'
request = require 'request'
crc32 = require('crc').crc32
mongo = require 'mongoskin'
_ = require 'underscore'

global.CONFIG = JSON.parse fs.readFileSync 'config.json'

GPlusAPI = require './lib/api'

api = new GPlusAPI CONFIG.refresh_token,'107023756258778911982'

db = mongo.db(CONFIG.mongodb,{w:true})
col = db.collection 'updates'

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
        timeout:5000
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

main = (gcb)->
    esc = make_esc gcb
    await fetch esc defer list

    hash = []
    for item,i in list
        item.hash = crc32(item.title)
        list[i].hash = item.hash
        hash.push item.hash

    await col.find({hash:{'$in':hash}},{_id:0,hash:1}).toArray esc defer results

    return gcb null,'nothing to post' if list.length == results.length
    results = _.flatten(results.map((item)->item.hash))
    item = _.find list,(item)->item.hash not in results
    return gcb null,'nothing to post' if not item?

    await api.linkPreview item.url,esc defer embed

    return gcb new Error "Cannot fetch #{item.url} from Google server." if not embed.succeeded

    await api.postPublicActivity item.title,embed.embedItem[0],esc defer activity

    await col.insert item,esc defer()


    db.close()
    return gcb null,activity

main(->console.dir arguments)
