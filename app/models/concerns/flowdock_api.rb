module FlowdockAPI
  def send_flowdock_notification(status)
    status == :success ? send_success_notification : send_failure_notification
  end

  def send_success_notification
    Shipit::flowdock_api(:success).push_to_team_inbox \
      subject: 'Deployed successfully!',
      content: '<p></p>',
      tags: ["shipit", "@#{user.login}"],
      link: "https://shipit.shopify.com#{url}"
  end

  def send_failure_notification
    Shipit::flowdock_api(:failure).push_to_team_inbox \
      subject: 'Deploy failed!',
      content: '<p></p>',
      tags: ["shipit", "@#{user.login}"],
      link: "https://shipit.shopify.com#{url}"
  end
end
