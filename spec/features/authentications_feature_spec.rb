require 'spec_helper'

feature 'Authentication' do
  describe 'login and get repositories from API' do
    let!(:state) { SecureRandom.hex }

    before do
      page.set_rack_session(state: state)
    end

    context 'state is incorrect' do
      scenario 'does not log in' do
        visit "/github_callback?state=wrongstate&code=#{SecureRandom.hex}"
        expect(page).to have_content('An error occurred; please try again')
      end
    end

    context 'rate limit is expired' do
      scenario 'shows rate limited page' do
        visit "/github_callback?state=#{state}&code=rate_limit_expired"
        expect(page).to have_content('Git Reports is currently experiencing heavy traffic.')
      end
    end

    context 'first user login' do
      scenario 'retrieves and stores repositories' do
        visit "/github_callback?state=#{state}&code=#{SecureRandom.hex}"
        expect(page).to have_content('Logged in!')
        expect(page).to have_content('CoolCode')
        expect(page).to have_content('PrettyProject')
        expect(page).to have_content('NeatOrgCode')
        expect(page).to have_content('NeatOrgProject')
      end
    end

    context 'first user login as org' do
      let!(:user) { create :user }
      let!(:org) { create :organization, name: 'neatorg' }
      let!(:org_repo) { create :repository, name: 'OldOrgCode', organization: org, users: [user] }
      let!(:existing_org_repo) { create :repository, name: 'NeatOrgStuff', github_id: 5_705_826, organization: org, users: [user] }

      before { visit "/github_callback?state=#{state}&code=#{SecureRandom.hex}" }

      scenario 'adds user to org' do
        expect(page).to have_content('neatorg')
      end

      scenario 'updates existing org repo' do
        expect(page).not_to have_content('NeatOrgStuff')
        expect(page).to have_content('NeatOrgCode')
      end

      scenario 'deletes old org repo' do
        expect(page).not_to have_content('OldOrgCode')
      end
    end

    context 'return user login' do
      let!(:org) { create :organization }
      let!(:user) { create :user, name: 'Old Name', access_token: 'access', organizations: [org] }
      let!(:repository) { create :user_repository, name: 'OldCode', users: [user] }
      let!(:existing_repo) { create :user_repository, name: 'NeatCode', github_id: 5_705_827, users: [user] }
      let!(:unlinked_repo) { create :user_repository, name: 'PrettyProject', github_id: 19_548_054 }
      let!(:unlinked_org_repo) { create :repository, name: 'NeatOrgProject', github_id: 19_548_055 }

      before { visit "/github_callback?state=#{state}&code=#{SecureRandom.hex}" }

      scenario 'updates user information' do
        expect(page).to have_content('George Git')
        expect(page).not_to have_content('Old Name')
      end

      scenario 'adds new repo to user' do
        expect(page).to have_content('PrettyProject')
      end

      scenario 'adds new org repo to user' do
        expect(page).to have_content('NeatOrgProject')
      end

      scenario 'updates existing repo' do
        expect(page).not_to have_content('NeatCode')
        expect(page).to have_content('CoolCode')
      end

      scenario 'deletes old repo' do
        expect(page).not_to have_content('OldCode')
      end
    end
  end

  describe 'logout' do
    let!(:user) { create :user, name: 'Joe Schmoe' }

    context 'user is logged in' do
      before { log_in user }

      scenario 'logs out the user' do
        visit logout_path
        expect(page).to have_content('Login')
        expect(page).not_to have_content('Joe Schmoe')
      end
    end
  end
end