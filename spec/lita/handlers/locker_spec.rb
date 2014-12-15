require 'spec_helper'

describe Lita::Handlers::Locker, lita_handler: true do
  it { is_expected.to route_event(:lock_attempt).to(:lock_attempt) }
  it { is_expected.to route_event(:unlock_attempt).to(:unlock_attempt) }

  label_examples = ['foobar', 'foo bar', 'foo-bar', 'foo_bar']
  resource_examples = ['foobar', 'foo.bar', 'foo-bar', 'foo_bar']

  label_examples.each do |l|
    it do
      is_expected.to route("(lock) #{l}").to(:lock)
      is_expected.to route("(unlock) #{l}").to(:unlock)
      is_expected.to route("(release) #{l}").to(:unlock)

      is_expected.to route("(Lock) #{l}").to(:lock)
      is_expected.to route("(Unlock) #{l}").to(:unlock)
      is_expected.to route("(Release) #{l}").to(:unlock)

      is_expected.to route("(lock) #{l} #this is a comment").to(:lock)
      is_expected.to route("(unlock) #{l} #this is a comment").to(:unlock)
      is_expected.to route("(release) #{l} #this is a comment").to(:unlock)

      is_expected.to route_command("lock #{l}").to(:lock)
      is_expected.to route_command("lock #{l} #this is a comment").to(:lock)
      is_expected.to route_command("unlock #{l}").to(:unlock)
      is_expected.to route_command("unlock #{l} #this is a comment").to(:unlock)
      is_expected.to route_command("steal #{l}").to(:steal)
      is_expected.to route_command("steal #{l} #this is a comment").to(:steal)

      is_expected.to route_command("locker status #{l}").to(:status)

      is_expected.to route_command("locker label create #{l}").to(:label_create)
      is_expected.to route_command("locker label delete #{l}").to(:label_delete)
      is_expected.to route_command("locker label show #{l}").to(:label_show)
      is_expected.to route_command("locker label add resource to #{l}")
        .to(:label_add)

      is_expected.to route_command("locker label remove resource from #{l}")
        .to(:label_remove)
    end
  end

  resource_examples.each do |r|
    it do
      is_expected.to route_command("locker status #{r}").to(:status)

      is_expected.to route_command("locker resource create #{r}")
        .to(:resource_create)

      is_expected.to route_command("locker resource delete #{r}")
        .to(:resource_delete)

      is_expected.to route_command("locker resource show #{r}")
        .to(:resource_show)
    end
  end

  it { is_expected.to route_command('locker resource list').to(:resource_list) }
  it { is_expected.to route_command('locker label list').to(:label_list) }
  it { is_expected.to route_command('locker list @alice').to(:user_list) }
  it { is_expected.to route_command('locker list Alice').to(:user_list) }

  it do
    is_expected.to route_http(:get, '/locker/label/foobar')
      .to(:http_label_show)

    is_expected.to route_http(:get, '/locker/resource/foobar')
      .to(:http_resource_show)
  end

  before do
    robot.auth.add_user_to_group!(user, :locker_admins)
  end

  let(:alice) do
    Lita::User.create('9001@hipchat', name: 'Alice', mention_name: 'alice')
  end

  let(:bob) do
    Lita::User.create('9002@hipchat', name: 'Bob', mention_name: 'bob')
  end

  describe '#lock' do
    it 'locks a label when it is available and has resources' do
      send_command('locker resource create foobar')
      send_command('locker label create bazbat')
      send_command('locker label add foobar to bazbat')
      send_command('lock bazbat # with a comment')
      expect(replies.last).to eq('(successful) bazbat locked')
      send_command('locker resource show foobar')
      expect(replies.last).to eq('Resource: foobar, state: locked')
    end

    it 'shows a warning when a label has no resources' do
      send_command('locker label create foobar')
      send_command('lock foobar')
      expect(replies.last).to eq('(failed) foobar has no resources, ' \
                                 'so it cannot be locked')
    end

    it 'shows a warning when a label is unavailable' do
      send_command('locker resource create r1')
      send_command('locker label create l1')
      send_command('locker label create l2')
      send_command('locker label add r1 to l1')
      send_command('locker label add r1 to l2')
      send_command('lock l1', as: alice)
      send_command('lock l2', as: alice)
      expect(replies.last).to eq('(failed) Label unable to be locked, ' \
                                 "blocked on:\nr1 - Alice")
    end

    it 'shows a warning when a label is taken by someone else' do
      send_command('locker resource create foobar')
      send_command('locker label create bazbat')
      send_command('locker label add foobar to bazbat')
      send_command('lock bazbat', as: alice)
      send_command('lock bazbat', as: bob)
      expect(replies.last).to eq('(failed) bazbat is locked by Alice (@alice)')
    end

    it 'shows an error when a label does not exist' do
      send_command('lock foobar')
      expect(replies.last).to eq('(failed) Label foobar does not exist.  To ' \
                                 'create it: "!locker label create foobar"')
    end

    # it 'locks a resource when it is available for a period of time' do
    #   send_command('locker resource create foobar')
    #   send_command('lock foobar 17m')
    #   expect(replies.last).to eq('foobar locked for 17 minutes')
    #   send_command('locker resource show foobar')
    #   expect(replies.last).to eq('Resource: foobar, state: locked')
    #   send_command('unlock foobar')
    #   send_command('lock foobar 12s')
    #   expect(replies.last).to eq('foobar locked for 17 seconds')
    #   send_command('unlock foobar')
    #   send_command('lock foobar 14h')
    #   expect(replies.last).to eq('foobar locked for 14 hours')
    # end
  end

  describe '#unlock' do
    it 'unlocks a label when it is available' do
      send_command('locker resource create foobar')
      send_command('locker label create bazbat')
      send_command('locker label add foobar to bazbat')
      send_command('lock bazbat')
      send_command('unlock bazbat # with a comment')
      expect(replies.last).to eq('(successful) bazbat unlocked')
    end

    it 'does not unlock a label when someone else locked it' do
      send_command('locker resource create foobar')
      send_command('locker label create bazbat')
      send_command('locker label add foobar to bazbat')
      send_command('lock bazbat', as: alice)
      send_command('unlock bazbat', as: bob)
      expect(replies.last).to eq('(failed) bazbat is locked by Alice (@alice)')
    end

    it 'shows a warning when a label is already unlocked' do
      send_command('locker resource create foobar')
      send_command('locker label create bazbat')
      send_command('locker label add foobar to bazbat')
      send_command('unlock bazbat')
      send_command('unlock bazbat')
      expect(replies.last).to eq('(successful) bazbat is unlocked')
    end

    it 'shows an error when a <subject> does not exist' do
      send_command('unlock foobar')
      expect(replies.last).to eq('(failed) Sorry, that does not exist')
    end
  end

  describe '#steal' do
    it 'unlocks a label from someone else when it is available' do
      send_command('locker resource create foobar')
      send_command('locker label create bazbat')
      send_command('locker label add foobar to bazbat')
      send_command('lock bazbat', as: alice)
      send_command('steal bazbat # with a comment', as: bob)
      expect(replies.last).to eq('(successful) bazbat stolen from ' \
                                 'Alice (@alice)')
    end

    it 'shows a warning when the label is already unlocked' do
      send_command('locker resource create foobar')
      send_command('locker label create bazbat')
      send_command('locker label add foobar to bazbat')
      send_command('steal bazbat # with a comment', as: alice)
      expect(replies.last).to eq('bazbat was already unlocked')
    end

    it 'shows a warning when the label is being stolen by the owner' do
      send_command('locker resource create foobar')
      send_command('locker label create bazbat')
      send_command('locker label add foobar to bazbat')
      send_command('lock bazbat', as: alice)
      send_command('steal bazbat # with a comment', as: alice)
      expect(replies.last).to eq('Why are you stealing the lock from yourself?')
    end

    it 'shows an error when a <subject> does not exist' do
      send_command('steal foobar')
      expect(replies.last).to eq('(failed) Sorry, that does not exist')
    end
  end

  describe '#status' do
    it 'shows the status of a label' do
      send_command('locker resource create bar')
      send_command('locker label create foo')
      send_command('locker label add bar to foo')
      send_command('locker status foo')
      expect(replies.last).to eq('Label: foo, state: unlocked')
      send_command('lock foo')
      send_command('locker status foo')
      expect(replies.last).to eq('Label: foo, state: locked, owner: Test User')
    end

    it 'shows the status of a resource' do
      send_command('locker resource create bar')
      send_command('locker label create foo')
      send_command('locker label add bar to foo')
      send_command('locker status bar')
      expect(replies.last).to eq('Resource: bar, state: unlocked')
      send_command('lock foo')
      send_command('locker status bar')
      expect(replies.last).to eq('Resource: bar, state: locked')
    end

    it 'shows an error if nothing exists with that name' do
      send_command('locker status foo')
      expect(replies.last).to eq('Sorry, that does not exist')
    end
  end

  describe '#label_list' do
    it 'shows a list of labels if there are any' do
      send_command('locker label create foobar')
      send_command('locker label create bazbat')
      send_command('locker label list')
      expect(replies.include?('Label: foobar, state: unlocked')).to eq(true)
      expect(replies.include?('Label: bazbat, state: unlocked')).to eq(true)
    end
  end

  describe '#label_create' do
    it 'creates a label with <name>' do
      send_command('locker label create foobar')
      expect(replies.last).to eq('Label foobar created')
    end

    it 'shows a warning when the <name> already exists as a label' do
      send_command('locker label create foobar')
      send_command('locker label create foobar')
      expect(replies.last).to eq('foobar already exists')
    end

    it 'shows a warning when the <name> already exists as a resource' do
      send_command('locker resource create foobar')
      send_command('locker label create foobar')
      expect(replies.last).to eq('foobar already exists')
    end
  end

  describe '#label_delete' do
    it 'deletes a label with <name>' do
      send_command('locker label create foobar')
      send_command('locker label delete foobar')
      expect(replies.last).to eq('Label foobar deleted')
    end

    it 'shows a warning when <name> does not exist' do
      send_command('locker label delete foobar')
      expect(replies.last).to eq('Label foobar does not exist.  To create ' \
                                 'it: "!locker label create foobar"')
    end
  end

  describe '#label_show' do
    it 'shows a list of resources for a label if there are any' do
      send_command('locker resource create whatever')
      send_command('locker label create foobar')
      send_command('locker label add whatever to foobar')
      send_command('locker label show foobar')
      expect(replies.last).to eq('Label foobar has: whatever')
    end

    it 'shows a warning if there are no resources for the label' do
      send_command('locker label create foobar')
      send_command('locker label show foobar')
      expect(replies.last).to eq('Label foobar has no resources')
    end

    it 'shows an error if the label does not exist' do
      send_command('locker label show foobar')
      expect(replies.last).to eq('Label foobar does not exist.  To create ' \
                                 'it: "!locker label create foobar"')
    end
  end

  describe '#label_add' do
    it 'adds a resource to a label if both exist' do
      send_command('locker resource create foo')
      send_command('locker label create bar')
      send_command('locker label add foo to bar')
      expect(replies.last).to eq('Resource foo has been added to bar')
      send_command('locker label show bar')
      expect(replies.last).to eq('Label bar has: foo')
    end

    it 'adds multiple resources to a label if all exist' do
      send_command('locker resource create foo')
      send_command('locker resource create baz')
      send_command('locker label create bar')
      send_command('locker label add foo to bar')
      send_command('locker label add baz to bar')
      send_command('locker label show bar')
      expect(replies.last).to match(/Label bar has:/)
      expect(replies.last).to match(/foo/)
      expect(replies.last).to match(/baz/)
    end

    it 'shows an error if the label does not exist' do
      send_command('locker label add foo to bar')
      expect(replies.last).to eq('Label bar does not exist.  To create ' \
                                 'it: "!locker label create bar"')
    end

    it 'shows an error if the resource does not exist' do
      send_command('locker label create bar')
      send_command('locker label add foo to bar')
      expect(replies.last).to eq('Resource foo does not exist')
    end
  end

  describe '#label_remove' do
    it 'removes a resource from a label if both exist and are related' do
      send_command('locker resource create foo')
      send_command('locker label create bar')
      send_command('locker label add foo to bar')
      send_command('locker label remove foo from bar')
      send_command('locker label show bar')
      expect(replies.last).to eq('Label bar has no resources')
    end

    it 'shows an error if they both exist but are not related' do
      send_command('locker resource create foo')
      send_command('locker label create bar')
      send_command('locker label remove foo from bar')
      expect(replies.last).to eq('Label bar does not have Resource foo')
    end

    it 'shows an error if the label does not exist' do
      send_command('locker label add foo to bar')
      expect(replies.last).to eq('Label bar does not exist.  To create ' \
                                 'it: "!locker label create bar"')
    end

    it 'shows an error if the resource does not exist' do
      send_command('locker label create bar')
      send_command('locker label add foo to bar')
      expect(replies.last).to eq('Resource foo does not exist')
    end
  end

  describe '#resource_list' do
    it 'shows a list of resources if there are any' do
      send_command('locker resource create foobar')
      send_command('locker resource create bazbat')
      send_command('locker resource list')
      expect(replies.last).to match(/Resource: foobar, state: unlocked/)
      expect(replies.last).to match(/Resource: bazbat, state: unlocked/)
    end
  end

  describe '#resource_create' do
    it 'creates a resource with <name>' do
      send_command('locker resource create foobar')
      expect(replies.last).to eq('Resource foobar created')
    end

    it 'shows a warning when the <name> already exists as a resource' do
      send_command('locker resource create foobar')
      send_command('locker resource create foobar')
      expect(replies.last).to eq('foobar already exists')
    end

    it 'shows a warning when the <name> already exists as a label' do
      send_command('locker label create foobar')
      send_command('locker resource create foobar')
      expect(replies.last).to eq('foobar already exists')
    end
  end

  describe '#resource_delete' do
    it 'deletes a resource with <name>' do
      send_command('locker resource create foobar')
      send_command('locker resource delete foobar')
      expect(replies.last).to eq('Resource foobar deleted')
    end

    it 'shows a warning when <name> does not exist' do
      send_command('locker resource delete foobar')
      expect(replies.last).to eq('Resource foobar does not exist')
    end
  end

  describe '#resource_show' do
    it 'shows the state of a <name> if it exists' do
      send_command('locker resource create foobar')
      send_command('locker resource show foobar')
      expect(replies.last).to eq('Resource: foobar, state: unlocked')
    end

    it 'shows a warning when <name> does not exist' do
      send_command('locker resource show foobar')
      expect(replies.last).to eq('Resource foobar does not exist')
    end
  end

  describe '#user_locks' do
    it 'shows if a user has taken any locks' do
      send_command('locker resource create foobar')
      send_command('locker label create bazbat')
      send_command('locker label add foobar to bazbat')
      Lita::User.create('9001@hipchat', name: 'Alice', mention_name: 'alice')
      send_command('lock bazbat', as: alice)
      send_command('locker list Alice')
      expect(replies.last).to eq("Label: bazbat\n")
    end

    it 'shows if a mention name has taken any locks' do
      send_command('locker resource create foobar')
      send_command('locker label create bazbat')
      send_command('locker label add foobar to bazbat')
      Lita::User.create('9001@hipchat', name: 'Alice', mention_name: 'alice')
      send_command('lock bazbat', as: alice)
      send_command('locker list @alice')
      expect(replies.last).to eq("Label: bazbat\n")
    end

    it 'shows an empty set if the user has not taken any locks' do
      send_command('locker resource create foobar')
      send_command('locker label create bazbat')
      send_command('locker label add foobar to bazbat')
      Lita::User.create('9001@hipchat', name: 'Alice', mention_name: 'alice')
      send_command('locker list Alice', as: alice)
      expect(replies.last).to eq('That user has no active locks')
      send_command('lock bazbat', as: alice)
      send_command('unlock bazbat', as: alice)
      send_command('locker list Alice', as: alice)
      expect(replies.last).to eq('That user has no active locks')
    end

    it 'shows a warning when the user does not exist' do
      send_command('locker list foobar')
      expect(replies.last).to eq('Unknown user')
    end
  end
end
