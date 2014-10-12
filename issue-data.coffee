_ = require 'underscore'

findJiraIssueForGhIssue = (name, ghIssue, jiraIssues) ->
  # make sure we're not mutating anything
  name = _.clone name
  ghIssue = _.clone ghIssue
  jiraIssues = _.clone jiraIssues

  _.find jiraIssues, (jiraIssue) ->
    trackMessage = "Tracked on GH: #{ghIssue.html_url}"
    return jiraIssue.fields.description.indexOf(trackMessage) >= 0

module.exports =
  linkIssues: (name, issues) ->
    # make sure we're not mutating anything
    name = _.clone name
    issues = _.clone issues

    _.reduce issues.gh, (linkedIssues, ghIssue) ->
      jiraIssue = findJiraIssueForGhIssue name, ghIssue, issues.jira
      linkedIssues.push { gh: ghIssue, jira: jiraIssue }
      return linkedIssues
    , []

  findUnlinkedJiraIssues: (jiraIssues, linkedIssues) ->
    # make sure we're not mutating anything
    jiraIssues = _.clone jiraIssues
    linkedIssues = _.clone linkedIssues

    _.reject jiraIssues, (jiraIssue) ->
      _.find linkedIssues, (linkedIssue) ->
        jiraIssue.id == linkedIssue.jira?.id

