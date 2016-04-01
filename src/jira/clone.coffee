_ = require "underscore"

Config = require "../config"
Create = require "./create"
Utils = require "../utils"

class Clone
  @fromTicketKeyToProject: (key, project, channel, msg) ->
    original = null
    cloned = null
    Create.fromKey(key)
    .then (issue) ->
      original = issue
      Utils.fetch("#{Config.jira.url}/rest/api/2/project/#{project}")
      .then (json) ->
        issueTypes = _(json.issueTypes).reject (it) -> it.name is "Sub-task"
        issueType = Utils.fuzzyFind issue.fields.issuetype.name, issueTypes, ['name']
        issueType = issueTypes[0] unless issueType
        Promise.reject "Unable to find a suitable issue type in #{project} that matches with #{original.fields.issuetype.name}" unless issueType

        Create.fromJSON
          fields:
            project:
              key: project
            summary: original.fields.summary
            labels: original.fields.labels
            description: """
              #{original.fields.description}

              Cloned from #{key}
            """
            issuetype: name: issueType.name
    .then (json) ->
      Create.fromKey(json.key)
    .then (ticket) ->
      cloned = ticket
      Utils.fetch "#{Config.jira.url}/rest/api/2/issueLink",
        method: "POST"
        body: JSON.stringify
          type:
            name: "Cloners"
          inwardIssue:
            key: original.key
          outwardIssue:
            key: cloned.key
          comment:
            body: """
              Cloned by #{msg.message.user.name} in ##{msg.message.room} on #{msg.robot.adapterName}
              https://#{msg.robot.adapter.client.team.domain}.slack.com/archives/#{msg.message.room}/p#{msg.message.id.replace '.', ''}
            """
    .then ->
      Utils.robot.emit "JiraTicketCreated", cloned, msg.message.room
      Utils.robot.emit "JiraTicketCloned", cloned, channel, key, msg if msg.message.room isnt channel
    .catch (error) ->
      Utils.robot.emit "JiraTicketCloneFailed", error, key, msg.message.room

module.exports = Clone
