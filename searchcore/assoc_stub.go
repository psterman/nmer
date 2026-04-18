//go:build !windows

package main

func getAssocBundleForExt(extWithDot string) assocBundle {
	return assocBundle{}
}

func getFileDescriptionFromPath(filePath string) string { return "" }
