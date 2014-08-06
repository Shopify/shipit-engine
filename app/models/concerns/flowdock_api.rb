module FlowdockAPI
  def flow(status)
    address = (status == :success) ? 'gaurav+pass@shopify.com' : 'gaurav+fail@shopify.com'

    Flowdock::Flow.new \
      api_token: "75127239beca7177ec14fcb716b6837e",
      source: "shipit",
      from: {
        name: 'Shipit',
        address: address
      }
  end

  def send_success_notification
    flow(:success).push_to_team_inbox(subject: 'Deployed successfully!', content: '<h2>It works!</h2> @Gaurav', tags: ["shipit", "@Gaurav"], link: "shipit.shopify.com")
  end

  def send_failure_notification
    flow(:success).push_to_team_inbox(subject: 'Deploy failed!', content: '<h2>It works!</h2> @Gaurav', tags: ["shipit", "@Gaurav"], link: "shipit.shopify.com")
  end
end
