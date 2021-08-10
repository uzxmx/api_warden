RSpec.describe ApiWarden do
  describe '.ward_by' do
    it 'wards by users' do
      ApiWarden.ward_by(:users)
      expect(ApiWarden.remove_ward_by(:users)).to eq(true)
    end

    it 'raises error when ward by the same scope for multiple times' do
      ApiWarden.ward_by(:users)
      expect { ApiWarden.ward_by(:users) }.to raise_error(RuntimeError)
      ApiWarden.remove_ward_by(:users)
    end

    it 'returns false when removing non-existent scope' do
      expect(ApiWarden.remove_ward_by(:users)).to eq(false)
    end
  end
end
