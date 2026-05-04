/// `status` query for `GET .../manager/all`, `hod/all`, `hr/all` (backend docs).
enum ResignationListQuery {
  all,
  pending,
  approved,
  rejected,
  withdrawn;

  /// Backend expects `All`, `Pending`, `Approved`, `Rejected`, `Withdrawn`.
  String get apiStatus => switch (this) {
        ResignationListQuery.all => 'All',
        ResignationListQuery.pending => 'Pending',
        ResignationListQuery.approved => 'Approved',
        ResignationListQuery.rejected => 'Rejected',
        ResignationListQuery.withdrawn => 'Withdrawn',
      };

  String get label => switch (this) {
        ResignationListQuery.all => 'All',
        ResignationListQuery.pending => 'Pending',
        ResignationListQuery.approved => 'Approved',
        ResignationListQuery.rejected => 'Rejected',
        ResignationListQuery.withdrawn => 'Withdrawn',
      };
}
