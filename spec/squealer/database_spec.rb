require 'spec_helper'
require 'mongo'

describe Squealer::Database do
  it "is a singleton" do
    Squealer::Database.respond_to?(:instance).should be_true
  end

  describe "import" do
    let(:databases) { Squealer::Database.instance }


    it "takes an import database" do
      databases.send(:instance_variable_get, '@import_dbc').should be_a_kind_of(Mongo::DB)
    end

    it "returns a squealer connection object" do
      databases.import.should be_a_kind_of(Squealer::Database::Connection)
    end

    it "delegates eval to Mongo" do
      databases.send(:instance_variable_get, '@import_dbc').eval('db.getName()').should == $db_name
      databases.import.eval('db.getName()').should == $db_name
    end
  end

  describe "source" do
    let(:databases) { Squealer::Database.instance }

    before { databases.import_from('localhost', 27017, $db_name) }

    it "returns a Source" do
      databases.import.source('foo').should be_a_kind_of(Squealer::Database::Source)
    end

    describe "Source::cursor" do
      it "returns a databases cursor" do
        databases.import.source('foo').cursor.should be_a_kind_of(Mongo::Cursor)
      end
    end

    context "an empty collection" do
      subject { databases.import.source('foo') }

      it "counts a total of zero" do
        subject.counts[:total].should == 0
      end

      it "counts zero imported" do
        subject.counts[:imported].should == 0
      end

      it "counts zero exported" do
        subject.counts[:exported].should == 0
      end
    end

    context "a collection with two documents" do
      let(:mongo) { Squealer::Database.instance.import.send(:instance_variable_get, '@dbc') }

      subject do
        mongo.collection('foo').save({'name' => 'Bar'});
        mongo.collection('foo').save({'name' => 'Baz'});
        source = databases.import.source('foo') # activate the counter
        source.send(:instance_variable_set, :@progress_bar, nil)
        Squealer::ProgressBar.send(:class_variable_set, :@@progress_bar, nil)
        source
      end

      after do
        mongo.collection('foo').drop
      end

      it "returns a Source" do
        subject.should be_a_kind_of(Squealer::Database::Source)
      end

      it "counts a total of two" do
        subject.counts[:total].should == 2
      end

      context "before iterating" do
        it "counts zero imported" do
          subject.counts[:imported].should == 0
        end

        it "counts zero exported" do
          subject.counts[:exported].should == 0
        end
      end

      context "after iterating" do
        before do
          subject.each {}
        end

        it "counts two imported" do
          subject.counts[:imported].should == 2
        end

        it "counts two exported" do
          subject.counts[:exported].should == 2
        end
      end

      context "real squeal" do
        # before { pending "interactive_view" }
        it "exports that stuff to SQL" do
          databases.export_to($db_adapter, 'localhost', $db_user, '', $db_name)
          databases.import.source("users").each do |user|
            target(:user) do |target|
              target.instance_variable_get('@row_id').should == user['_id'].to_s
              assign(:organization_id)
              assign(:name)

              #TODO: Update README to highlight that all embedded docs should have an _id
              # as all Ruby mappers for MongoDB make one. (according to Durran)
              user.activities.each do |activity|
                target(:activity) do |target|
                  assign(:user_id)
                  assign(:name)
                  assign(:due_date)
                end
              end
            end
          end
        end
      end

    end

  end

  describe "export" do
    let(:databases) { Squealer::Database.instance }

    it "takes an export database" do
      databases.export_to($db_adapter, 'localhost', $db_user, '', $db_name)
      databases.instance_variable_get('@export_do').should_not be_nil
    end
  end

  describe "upsertable?" do
    subject { Squealer::Database.instance }

    context "mysql connection" do
      before do
        subject.export_to('mysql', 'localhost', 'root', '', 'mysql')
      end

      it { should be_upsertable }
    end

    context "postgres connection" do
      before do
        subject.export_to('postgres', 'localhost', '', '', 'postgres')
      end

      it { should_not be_upsertable }
    end
  end

end
