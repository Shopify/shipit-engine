module FlowdockNotifications
  def send_flowdock_notification(success:)
    subject = success ? 'Deployed successfully!' : 'Deploy failed!'

    Shipit::flowdock_api(success: success).push_to_team_inbox \
      subject: subject,
      content: '<p></p>',
      tags: ["shipit", "@#{user.login}"],
      link: "https://shipit.shopify.com#{stack_deploy_path}"
  end
end
