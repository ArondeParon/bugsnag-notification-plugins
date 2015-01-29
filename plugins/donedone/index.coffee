require "sugar"

NotificationPlugin = require "../../notification-plugin"

class DoneDone extends NotificationPlugin
  @baseUrl: (config) ->
    "https://#{config.subdomain}.mydonedone.com/issuetracker/api/v2/projects/#{config.projectId}"

  @issuesUrl: (config) ->
    "#{@baseUrl(config)}/issues.json"

  @commentUrl: (config, issueId) ->
    "#{@baseUrl(config)}/issues/#{issueId}/comments.json"

  @issueWebUrl: (config, issueId) ->
    "#{@baseUrl(config)}/issues/#{issueId}"

  @sendRequest: (req, config) ->
    req
      .timeout(4000)
      .auth(config.username, config.apitoken)
      .type("form")
      .buffer(true)
      .set({"Accept": "application/json"})
      # .set({"Accept-Encoding" : "gzip,sdch"})

  @addCommentToIssue: (config, issueId, comment) ->
    @sendRequest(@request.post(@commentUrl(config, issueId)), config)
      .send({"comment": comment})
      .on("error", console.error)
      .end()

  @openIssue: (config, event, callback) ->
    # Build the request
    params =
      "title": "#{event.error.exceptionClass} in #{event.error.context}".truncate(5000)
      "priority_level_id": "1"
      "fixer_id": "#{config.defaultFixerId}"
      "tester_id": "#{config.defaultTesterId}"
      "tags": (config?.labels || "bugsnag").trim()
      "description":
        """
        *#{event.error.exceptionClass}* in *#{event.error.context}*
        #{event.error.message if event.error.message}
        #{event.error.url}

        *Stacktrace:*
        #{@basicStacktrace(event.error.stacktrace)}
        """.truncate(20000)

    # Send the request to the url
    req = @sendRequest(@request.post(@issuesUrl(config)), config)
      .send(params)
      .on "error", (err) ->
        callback(err)
      .end (res) ->
        return callback(res.error) if res.error
        callback null,
          id: res.id
          url: @issueWebUrl(config, res.id)
    # console.log req

  @receiveEvent: (config, event, callback) ->
    if event?.trigger?.type == "reopened"
      if event.error?.createdIssue?.id
        @addCommentToIssue(config, event.error.createdIssue.id, @markdownBody(event))
    else
      @openIssue(config, event, callback)

module.exports = DoneDone
