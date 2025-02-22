require 'spec_helper'
require 'isolation_segment_assign'
require 'messages/isolation_segments_list_message'
require 'fetchers/isolation_segment_list_fetcher'

module VCAP::CloudController
  RSpec.describe IsolationSegmentListFetcher do
    let(:filters) { {} }
    let(:message) { IsolationSegmentsListMessage.from_params(filters) }
    subject { IsolationSegmentListFetcher.fetch_all(message) }

    let!(:isolation_segment_model_1) { VCAP::CloudController::IsolationSegmentModel.make }
    let!(:isolation_segment_model_2) { VCAP::CloudController::IsolationSegmentModel.make(name: 'frank') }
    let!(:isolation_segment_model_3) { VCAP::CloudController::IsolationSegmentModel.make }

    let(:org1) { VCAP::CloudController::Organization.make }
    let(:org2) { VCAP::CloudController::Organization.make }
    let(:org3) { VCAP::CloudController::Organization.make }

    let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

    before do
      assigner.assign(isolation_segment_model_1, [org1])
      assigner.assign(isolation_segment_model_2, [org2])
      assigner.assign(isolation_segment_model_3, [org3])
    end

    describe '#fetch_all' do
      it 'returns a Sequel::Dataset' do
        expect(subject).to be_a(Sequel::Dataset)
      end

      it 'returns all isolation segments' do
        isolation_segment_models = subject.all

        shared_isolation_segment_model = VCAP::CloudController::IsolationSegmentModel[guid: VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID]
        expect(isolation_segment_models).to match_array([shared_isolation_segment_model, isolation_segment_model_1, isolation_segment_model_2, isolation_segment_model_3])
      end

      context 'filters' do
        context 'by isolation segment guids' do
          let(:filters) { { guids: [isolation_segment_model_1.guid] } }

          it 'filters by guids' do
            isolation_segment_models = subject.all
            expect(isolation_segment_models).to contain_exactly(isolation_segment_model_1)
          end
        end

        context 'by isolation segment names' do
          let(:filters) { { names: [isolation_segment_model_2.name.capitalize, isolation_segment_model_3.name] } }

          it 'filters by names and ignores case' do
            isolation_segment_models = subject.all
            expect(isolation_segment_models).to contain_exactly(isolation_segment_model_2, isolation_segment_model_3)
          end
        end

        context 'by organization guids' do
          let(:filters) { { organization_guids: [org1.guid, org2.guid] } }

          it 'filters by organization guids' do
            isolation_segment_models = subject.all
            expect(isolation_segment_models).to contain_exactly(isolation_segment_model_1, isolation_segment_model_2)
          end
        end

        context 'filtering label selectors' do
          let(:filters) { { 'label_selector' => 'key=value' } }
          let!(:label) { IsolationSegmentLabelModel.make(resource_guid: isolation_segment_model_3.guid, key_name: 'key', value: 'value') }

          it 'returns the correct set of isosegs' do
            isolation_segment_models = subject.all
            expect(isolation_segment_models).to match_array([isolation_segment_model_3])
          end
        end
      end
    end

    describe '#fetch_for_organizations' do
      let(:fetcher) { IsolationSegmentListFetcher }
      let(:org_guids_query_empty) { Organization.where(id: -1).select(:guid) }
      let(:org_guids_query_org1_org2) { Organization.where(id: [org1.id, org2.id]).select(:guid) }

      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_for_organizations(message, org_guids_query: org_guids_query_empty)
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'fetches only those isolation segments associated with the specified orgs' do
        isolation_segment_models = fetcher.fetch_for_organizations(message, org_guids_query: org_guids_query_org1_org2).all
        expect(isolation_segment_models).to contain_exactly(isolation_segment_model_1, isolation_segment_model_2)
      end

      it 'returns no isolation segments when the list of org guids is empty' do
        isolation_segment_models = fetcher.fetch_for_organizations(message, org_guids_query: org_guids_query_empty).all
        expect(isolation_segment_models).to be_empty
      end

      context 'filtering by isolation_segment_names' do
        let(:filters) { { names: [isolation_segment_model_2.name.capitalize, isolation_segment_model_3.name] } }

        it 'filters by names and ignores case' do
          isolation_segment_models = fetcher.fetch_for_organizations(message, org_guids_query: org_guids_query_org1_org2).all
          expect(isolation_segment_models).to contain_exactly(isolation_segment_model_2)
        end
      end

      context 'filtering by isolation_segment_guids' do
        let(:filters) { { guids: [isolation_segment_model_1.guid] } }

        it 'filters by guids' do
          isolation_segment_models = fetcher.fetch_for_organizations(message, org_guids_query: org_guids_query_org1_org2).all
          expect(isolation_segment_models).to contain_exactly(isolation_segment_model_1)
        end
      end

      context 'by organization guids' do
        let(:filters) { { organization_guids: [org1.guid] } }

        it 'filters by organization guids' do
          isolation_segment_models = fetcher.fetch_for_organizations(message, org_guids_query: org_guids_query_org1_org2).all
          expect(isolation_segment_models).to contain_exactly(isolation_segment_model_1)
        end
      end
    end
  end
end
