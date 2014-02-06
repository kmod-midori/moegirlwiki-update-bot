http = require('http')
wait = require 'wait.for'
request = require 'request'
EventEmitter = require('eventemitter3')
mongoose = require('mongoose')
GPlusAPI = require './api'
_ = require 'lodash'
{scheduleJob}=require('pomelo-schedule')
l = require('tracer').colorConsole
  format:'{{timestamp}} <{{title}}>{{message}}'
  dateformat : "HH:MM:ss"
api = new GPlusAPI(process.env.REFRESH_TOKEN,process.env.GPLUS_UID)

mongoose.connect process.env.MONGODB

`
var http = require('http');
http.createServer(function (req, res) {
    res.writeHead(200, {'Content-Type': 'text/plain'});
    res.end('hello, i know nodejitsu\n');
}).listen(80);
`


recentChangeSchema = new mongoose.Schema
  rcid:
    type:Number
    index:true

recentChangeModel = mongoose.model 'RecentChange',recentChangeSchema

maxRetry = 3
retries = 0
updateJob = ->wait.launchFiber ->
  try
    rep = wait.for request,
      url:'http://zh.moegirl.org/api.php?format=json&action=query&list=recentchanges'+
      '&rcnamespace=0&rctoponly=1&rcprop=flags|title|ids'
      method:'GET'
      timeout:10000
      headers:
        'User-Agent':'UpdateBot4G+'
    throw new Error(rep.statusCode) if rep.statusCode is not 200
  catch e
    if retries < maxRetry
      setTimeout updateJob,1000*60
      retries++
      l.error 'Moegirlwiki request error,retrying in 1 minute.'
    return l.error 'Moegirlwiki request error:%s',e.toString()

  try
    rc = JSON.parse(rep.body).query.recentchanges
  catch e
    if retries < maxRetry
      setTimeout updateJob,1000*60
      retries++
      l.error 'Moegirlwiki API error,retrying in 1 minute.'
    return l.error 'Moegirlwiki API error:%s',e.toString()

  rc = rc.filter (i)->not i.bot?
  rcids = for item in rc
    item.rcid
  try
    skip = wait.forMethod recentChangeModel.find().in('rcid',rcids).select('rcid'),'exec'
  catch e
    if retries < maxRetry
      setTimeout updateJob,1000*60
      retries++
      l.error 'Mongodb query error,retrying in 1 minute.'
    return l.error 'Mongodb query error:%s',e.toString()

  return l.info 'Nothing to post.' if rc.length == skip.length
  item = _.find rc,(item)->item.rcid not in skip
  item.url = 'http://zh.moegirl.org/' + encodeURIComponent(item.title)
  try
    embed = wait.for(api.linkPreview,item.url)
    throw new Error() if not embed.succeeded
  catch e
    if retries < maxRetry
      setTimeout updateJob,1000*60
      retries++
      l.error 'Embed fetching error,retrying in 1 minute.'
    return l.error 'Cannot fetch %s from Google server:%s',item.url,e.toString()
  str = """
          条目： ##{item.title.replace(' ','_')}

          更新了哦！不来看看么？
          传送在此：

          →_→ #{item.url}
          """
  try
    activity = wait.for api.postPublicActivity,str,embed.embedItem[0]
  catch e
    if retries < maxRetry
      setTimeout updateJob,1000*60
      retries++
      l.error 'Google+ posting error,retrying in 1 minute.'
    return l.error 'Google+ posting error:%s',e.toString()
  recentChangeModel.create {rcid:item.rcid}
  l.info 'Finished posting:%s',activity.stream.update[0].updateId

scheduleJob {
  period : 1200000
},updateJob

l.info 'Main loop started.'



