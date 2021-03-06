require 'spec_helper'

describe Lita::Handlers::LockerLabels, lita_handler: true do
  before do
    robot.auth.add_user_to_group!(user, :locker_admins)
    Lita.config.robot.adapter = :hipchat
  end

  label_examples = ['foobar', 'foo bar', 'foo-bar', 'foo_bar']

  label_examples.each do |l|
    it do
      is_expected.to route_command("locker label create #{l}").to(:create)
      is_expected.to route_command("locker label delete #{l}").to(:delete)
      is_expected.to route_command("locker label show #{l}").to(:show)
      is_expected.to route_command("locker label add resource to #{l}").to(:add)
      is_expected.to route_command("locker label add foo, bar to #{l}").to(:add)
      is_expected.to route_command("locker label remove resource from #{l}").to(:remove)
      is_expected.to route_command("locker label remove foo, bar from #{l}").to(:remove)
    end
  end

  multi_label_examples = ['foo, bar', 'foo,bar']

  multi_label_examples.each do |l|
    it do
      is_expected.to route_command("locker label create #{l}").to(:create)
      is_expected.to route_command("locker label delete #{l}").to(:delete)
    end
  end

  it { is_expected.to route_command('locker label list').to(:list) }

  describe '#label_list' do
    it 'shows a list of labels if there are any' do
      send_command('locker label create foobar')
      send_command('locker label create bazbat')
      send_command('locker label list')
      sleep 1 # TODO: HAAAACK.  Need after to have a more testable behavior.
      expect(replies.include?('foobar is unlocked')).to eq(true)
      expect(replies.include?('bazbat is unlocked')).to eq(true)
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

    it 'accepts a comma-separated list of labels' do
      send_command('locker label create foo, bar,baz')
      expect(replies.last).to eq('Label foo created, Label bar created, Label baz created')
    end

    it 'handles comma-separated labels nicely when a label already exists' do
      send_command('locker label create bar')
      send_command('locker label create foo, bar,baz')
      expect(replies.last).to eq('Label foo created, bar already exists, Label baz created')
    end

    # it 'shows a warning when the <name> already exists as a resource' do
    #   send_command('locker resource create foobar')
    #   send_command('locker label create foobar')
    #   expect(replies.last).to eq('foobar already exists')
    # end
  end

  describe '#label_delete' do
    it 'deletes a label with <name>' do
      send_command('locker label create foobar')
      send_command('locker label delete foobar')
      expect(replies.last).to eq('Label foobar deleted')
    end

    it 'shows a warning when <name> does not exist' do
      send_command('locker label delete foobar')
      expect(replies.last).to eq('Label foobar does not exist.  To create it: "!locker label create foobar"')
    end

    it 'accepts a comma-separated list of labels' do
      send_command('locker label create foo, bar, baz')
      send_command('locker label delete foo, bar,baz')
      expect(replies.last).to eq('Label foo deleted, Label bar deleted, Label baz deleted')
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
      expect(replies.last).to eq('Label foobar does not exist.  To create it: "!locker label create foobar"')
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

    it 'adds multiple resources to a label when given as a comma-separated list' do
      send_command('locker resource create foo')
      send_command('locker resource create bar')
      send_command('locker label create baz')
      send_command('locker label add foo, bar to baz')
      expect(replies.last).to eq('Resource foo has been added to baz, Resource bar has been added to baz')
    end

    it 'shows an error if the label does not exist' do
      send_command('locker label add foo to bar')
      expect(replies.last).to eq('Label bar does not exist.  To create it: "!locker label create bar"')
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

    it 'removes multiple resources to a label when given as a comma-separated list' do
      send_command('locker resource create foo')
      send_command('locker resource create bar')
      send_command('locker label create baz')
      send_command('locker label add foo, bar to baz')
      send_command('locker label remove foo, bar from baz')
      expect(replies.last).to eq('Resource foo has been removed from baz, Resource bar has been removed from baz')
    end

    it 'shows an error if the label does not exist' do
      send_command('locker label add foo to bar')
      expect(replies.last).to eq('Label bar does not exist.  To create it: "!locker label create bar"')
    end

    it 'shows an error if the label does not exist when given a list of resources' do
      send_command('locker label add foo, baz to bar')
      expect(replies.last).to eq('Label bar does not exist.  To create it: "!locker label create bar"')
    end

    it 'shows an error if the resource does not exist' do
      send_command('locker label create bar')
      send_command('locker label add foo to bar')
      expect(replies.last).to eq('Resource foo does not exist')
    end

    it 'shows an error if a resource in a list does not exist' do
      send_command('locker label create bar')
      send_command('locker resource create baz')
      send_command('locker label add foo, baz to bar')
      expect(replies.last).to eq('Resource foo does not exist, Resource baz has been added to bar')
    end
  end
end
