package assets

init_assets :: proc(asset_catalog: ^Asset_Catalog, allocator := context.allocator) {
  asset_catalog.models = make(map[string]ThreeD_Model, 16, allocator);
}